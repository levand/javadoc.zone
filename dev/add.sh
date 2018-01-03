AWS_PROFILE=javadoc.zone lambda-local -E '{"AWS_REGION": "us-east-1", "CLASSES_TABLE": "jdz-classes-dev", "HOSTS_TABLE": "jdz-hosts-dev"}' -t 30 -l lambdas/add.js -e dev/samples/add.json | cat
