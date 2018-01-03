# javadoc.zone

Javadoc registry and search service

## Architecture

Custom-built serverless architecture, on AWS. Uses:

- S3 for static files
- Lambda for dynamic services
- DynamoDB as a data store
- Terraform to orchestrate deployments

## Project Map

The repository contains the following directories:

- `/lambdas` - Source code for the lambda services. These are written in JavaScript and structured as a Node project (see `package.json`)
- `/site` - Source code for the static site, which is built using a tiny Node project. CSS files are plain CSS. HTML files are templates using Handlebars, using [handlebars-generator](https://www.npmjs.com/package/handlebars-generator). Other JS files in `/site` are just sample data for the templates. To run the static build, run the `build.sh` script in this directory, which will build the site into a `.build` directory.
- `/terraform` - Contains the Terraform deployment config.
- `/dev` - Contains some scripts to run the lambdas locally, for faster iteration when developing. Requires the `lambda-local` NPM package to be installed globally.

## Deployment

To deploy an instance of the system, follow these steps. Replace
`<root>` with the project's root directory.

1. `cd <root>/lambdas && npm install`
1. `cd <root>/site && npm install`
1. `site/build.sh`
1. Ensure you have an [AWS credentials profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-config-files.html) with a profile named `javadoc.zone`, with full permissions to create and destroy S3 Buckets, DynamoDB tables, Lambda functions, and API Gateway resources.
1. Change the S3 bucket name that the Terraform backend uses to store state in `<root>/terraform/main.tf`. You must have write permissions to the bucket you specify.
1. `cd <root>/terraform && terraform init`
1. `cd <root>/terraform && terraform workspace <env>`, where `<env>` is the name you want to identify the environment you're deploying (e.g, "dev" or "prod".)
1. `cd <root>/terraform && terraform apply`

You should now be able to visit the URL emitted by `terraform apply` and use the application.

To destroy your deployment, run `<root>/terraform && terraform destroy`. Note that this removes the deployment entirely including all data and databases.

## License

The code in this repository, except where noted otherwise, is copyright Luke VanderHart, 2018. You are granted permission to freely read, copy, deploy, edit and share it for the following purposes:

- personal education
- development and testing for the purpose of contributing back to this repository
- non-public deployments

Permission is NOT granted to run additional public instances of this service.
