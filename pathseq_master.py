###                                            -*- Mode: Python -*-
###                                            -*- coding UTF-8 -*-
### pathseq_master.py
### Copyright 2023 RPM Bioinfo Solutions
### Author :  Adam-Nicolas Pelletier
### Last modified On: 2023-05-11
### Version 2.0


import os
import pandas as pd
import numpy as np
import subprocess
import sys
import argparse
import re
import boto3
import botocore
import getpass
import json
from pathlib import Path
from datetime import datetime
import platform

from flatten_dict import flatten
from flatten_dict import unflatten

from aws_utils.s3_transfer import *


########################################################################################################################################################
############################################################## LOAD USER DATA ##########################################################################
amzn2_check = re.compile("amzn2")
if re.search(amzn2_check, platform.release()):
	usern = "ec2-user"
else:
	usern = getpass.getuser()

rootdir = "/home/%s/user_data/" % usern



awsdata = json.load(open(rootdir + "aws_settings.json"))
usrdt = pd.read_csv(rootdir +"email.csv")
genome_dict = json.load(open(rootdir + "genome_db.json"))
default_config = "/home/%s/conf/aws.config" % usern
config_help = "nextflow [c]onfiguration file. Defaults to the %s." % default_config


########################################################################################################################################################
########################################################################################################################################################



########################################################################################################################################################
########################################################## USER INPUT  AND OUTPUT ######################################################################



cwd = os.path.dirname(os.path.realpath(__file__))

pd.options.mode.chained_assignment = None  # default='warn

aws_cred = "/home/%s/.aws/credentials" % usern

if os.path.isfile(aws_cred):
	prof = boto3.session.Session(profile_name = awsdata["aws_profile"])
else:
	prof = boto3.session.Session()


s3 = boto3.resource('s3', region_name= awsdata["aws_region"])



parser = argparse.ArgumentParser(description="""launches the Path-seq preprocessing pipeline.""" )
parser._action_groups.pop()
required = parser.add_argument_group('required arguments')
optional = parser.add_argument_group('optional arguments')


required.add_argument("-i","--input", required=True,
					help="[i]nput directory/S3 bucket with raw data (required)")
required.add_argument("-o","--output_bucket", required=True,
					help="[o]utput S3 bucket directory with outputdata (required)")
required.add_argument("-g", "--genome", required = True, choices= genome_dict.keys(),
					help="reference [g]enome for alignment. (required)")
required.add_argument("-k", "--kraken", required = True, default = "standard", choices=['viral', 'standard', 'eupath'],
					help="[k]raken index for alignment. (required). Defaults to standard. More details at 'https://benlangmead.github.io/aws-indexes/k2'")

optional.add_argument("-e","--email" ,
					help="[e]mail for notifications of pipeline status (optional) if NOT for the user.")
optional.add_argument("--sampleglob" ,	
					help="Glob to capture samplename (optional) ")
optional.add_argument("--dryrun", action="store_true",
					help="Activates test mode, which does not launch the run. on AWS Batch. Defaults to FALSE. Returns the Nextflow command. Useful if you only wish to generate the samplesheet, but supply your own '-params_file'.")
optional.add_argument("--config", default = default_config,
					help=config_help)
optional.add_argument("-t", "--skiptrim", action="store_true",
					help="deactivates read [t]rimming with cutadapt. Uses adapters specified with adapter1 and adapter2 parameters.")
optional.add_argument("--adapter1", default = "NONE",
					help="adapter sequence (#1) used for trimming. Defaults to 'NONE'")
optional.add_argument("--adapter2", default = "NONE",
					help="adapter sequence (#2) used for trimming., Defauls to 'NONE'")

args = parser.parse_args()


inputDir = args.input
outputDir = args.output_bucket
genome = args.genome
krakendb = args.kraken
emailp = args.email
sglob = args.sampleglob
dryrun = args.dryrun
config = args.config
trim = args.skiptrim
adapter1 = args.adapter1
adapter2 = args.adapter2



########################################################################################################################################################
########################################################################################################################################################

# Scan for s3 validity
input_s3 = s3_check(inputDir, s3)
output_s3 = s3_check(outputDir, s3)

usr_log = getpass.getuser()

# Verify if output is a S3 location
if output_s3:
	pass
else:
	print("Invalid output location. Specify a valid S3 location. Aborting...")
	sys.exit()


if emailp == None:
	email = usrdt[usrdt["Username"] == usr_log]["email"][0]
	if(len(email) == 0):
		print("No email stored in internal records for user " + usr_log + ". Either add user or supply email with the -e parameter if you wish to receive email notifications. ")
		email = False
else:
	email = emailp


def check_email(s):
    pat = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b'
    if re.match(pat,s):
        pass
    else:
        print("Invalid Email")
        sys.exit()

if email is not False:
	check_email(email)



# inputDir_abs = os.path.abspath(inputDir.rstrip(os.sep))
# outputDir_abs = os.path.abspath(outputDir.rstrip(os.sep))
date_time = datetime.now().strftime("%Y%m%d_%H%M")

# fileLS_raw = list()
# for (dirpath, dirnames, filenames) in os.walk(inputDir_abs):
# 	fileLS_raw += [os.path.join(dirpath, file) for file in filenames]


if input_s3:
	fileLS_uri = s3_file_list(inputDir, s3)
	reg = re.compile('f(ast|)q($|.gz$)')
	fileLS_uri = [i for i in fileLS_uri if re.search(reg, i)]
	#fileLS = [i for i in fileLS_uri if re.search(reg, i)]
	if len(fileLS_uri) == 0:
		print("There are no fastqs in the specified input URI. Try again. Exiting...")
		sys.exit()
	fileLS = fileLS_uri

else :
	inputDir_abs = os.path.abspath(inputDir.rstrip(os.sep))
	fileLS = list(Path(inputDir_abs).rglob("*.f(ast|)q($|.gz$)"))
	if len(fileLS) == 0:
		print("There are no fastqs in the specified input directory. Try again. Exiting...")
		sys.exit()



## Filter samples based on the glob
sample_dict = {}

if sglob != None:
	rglob = re.compile(sglob)
	fileLS = [i for i in fileLS if re.search(rglob, i)]
	if len(fileLS) == 0:
		print("No files matching the glob " + sglob + " in the input location. Exiting...")
		sys.exit()


### remove index files if present. 
iglob = re.compile("^((?!_I[1-4]_).)*$")  ### remove index files if present. 
fileLS = [i for i  in fileLS if re.search(iglob, i)]


#print(fileLS)
for i in fileLS:
	strip = re.sub(r'\.f(ast|)q($|.gz$)', '', i) 
	strip = re.sub(r'_001', '', strip) 
	end = re.sub(r'.*_','', strip)
	rtest = end.find('R')
	if rtest == -1:
		end = "R" + end

	strip= os.path.basename(re.sub(r'_(R|)[12]$', '', strip))
	lane = re.sub(r'.*_','', strip)

	if sglob != None:
		glob_match = re.search(rglob,strip).group()
		sample = glob_match
		
	else:
		sample = os.path.basename(re.sub(r'_L00[1-4]$', '', strip))
	
	ltest = lane.find('L00[1-4]')
	if ltest == -1:
		lane = "L001"

	
	if sample in sample_dict:
		dict_tmp = flatten(sample_dict)
		
		if lane in sample_dict[sample].keys():

			sample_dict[sample][lane].update({end :i})
		else:
			dict_tmp[(sample_dict,lane)] = end
			sample_dict = unflatten(dict_tmp)

	else:
		sample_dict[sample] = {lane : {end :i}}
	



# Path(outputDir_abs).mkdir(parents=True, exist_ok=True)
samplefile = pd.DataFrame.from_dict({(i,j): sample_dict[i][j]
										for i in sample_dict.keys()
										for j in sample_dict[i].keys()},
									orient = 'index')
samplefile = samplefile.reset_index(level = 1)
samplefile = samplefile.drop(columns=["level_1"])


samplesheet = samplefile.copy(deep = True)
samplefile["location"] = samplefile["R1"]
samplefile["location"] = samplefile["location"].apply(lambda x: os.path.splitext(os.path.dirname(x))[0])
samplefile["R1"] = samplefile["R1"].apply(lambda x: os.path.basename(x))

if "R2" in list(samplefile.columns):
	samplefile["R2"] = samplefile["R2"].apply(lambda x: os.path.splitext(os.path.basename(x))[0])
else:
	print("No reverse strand fastq files detected. Pathseq requires paired-end data. ")
	sys.exit()

samplesheet = samplesheet.rename( {'R1' : 'fastq_1', 'R2' : 'fastq_2'}, axis  = 1)
samplesheet = samplesheet[["fastq_1", "fastq_2"]]



print("\n\nDataset contains " + str(len(set(list(samplefile.index)))) + " samples:" )
#print(list(sample_dict.keys()))
print(samplefile)
prompt_check = False
while prompt_check is False:
	inp = input("\n\nContinue ? (y/n) :  ")
	print(inp)
	if inp.upper() == "Y":
		prompt_check = True
	elif inp.upper() != "N":
		print("Invalid answer (y/n)\n")
	else:
		sys.exit()


# pd.options.display.max_colwidth = 100
# print(samplefile)
sampleOut = os.sep.join([awsdata["nf_samplesheets"], 'sample_sheet_pathseq_%s.csv']) % date_time

samplesheet.to_csv(sampleOut, header = True, index_label = "sample", sep = ",")


# sampleBatch = re.sub(r'efs/', '', sampleOut)

fasta = genome_dict[genome]["fasta"]
gtf = genome_dict[genome]["gtf"]
kraken_location = "%s/kraken_db/%s" % (awsdata["reference_bucket"], krakendb)
kraken_ls = s3_check(kraken_location, s3)
if kraken_ls is False:
	print("Specified Kraken database not found in the reference bucket. First place the specified kraken index at %s" % kraken_location) 
	sys.exit()

cmd = ["nextflow run pathseq.nf \\" ,		
		"--input ", sampleOut, " \\",
		"--outdir " ,outputDir , " \\" ,
		"--fasta " , fasta , " \\" ,
		"--gtf ", gtf, " \\",
		"--kraken ", kraken_location, " \\",
		"-bg \\", 
		"-c ", config]

if email is not False:
	cmd.extend([" \\", "-email ", email])
if trim:
	cmd.extend([" \\", "--trim ", "false", " \\", "--adapter1 ", adapter1, " \\", "--adapter2", adapter2])


cmd_string = ('').join(cmd)

screen_session = "pathseq_%s" % date_time

screen_create = "screen -dmS %s" % screen_session


if dryrun is False:
	print("Launching Nexflow...")
	os.system(screen_create)
	print("Launching Nextflow Path-seq run in screen session %s" % screen_session) 
	print("Check progress with 'screen -RD %s', and resume with CTRL+A followed by CTRL+D\n" % screen_session) 
	screen_cmd = "screen -S %s -X stuff '%s\n'" % (screen_session, cmd_string)
	os.system(screen_cmd)
else:
	print("\nNEXTFLOW COMMAND:\n\n")
	print(cmd_string)




