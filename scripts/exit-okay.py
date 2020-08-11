import sys
import csv

reader = csv.DictReader(sys.stdin, delimiter='\t')
for row in reader:
    retcode = int(row['Exitval'])
    if retcode:
        sys.exit(retcode)
