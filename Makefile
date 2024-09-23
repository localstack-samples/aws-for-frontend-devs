usage:		    ## Shows usage for this Makefile
	@cat Makefile | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install:        ## Install dependencies
	which awslocal || pip install awscli-local[ver1]
	which cdklocal || npm install -g aws-cdk-local aws-cdk
	cd api-gateway && npm install
	cd cf-s3 && npm install
	cd dynamodb && npm install
	cd lambda && npm install
	cd s3 && npm install

deploy-s3:         ## Deploy the app to LocalStack
	cd s3 && \
	    cdklocal bootstrap && \
	    cdklocal deploy --require-approval=never

deploy-cf-s3:         ## Deploy the app to LocalStack
	cd cf-s3 && \
	    cdklocal bootstrap && \
	    cdklocal deploy --require-approval=never

deploy-lambda:         ## Deploy the app to LocalStack
	cd lambda && \
	    cdklocal bootstrap && \
	    cdklocal deploy --require-approval=never

deploy-api-gateway:         ## Deploy the app to LocalStack
	cd api-gateway && \
	    cdklocal bootstrap && \
	    cdklocal deploy --require-approval=never

deploy-dynamodb:         ## Deploy the app to LocalStack
	cd api-gateway && \
	    cdklocal bootstrap && \
	    cdklocal deploy --require-approval=never

.PHONY: usage install deploy-s3 deploy-cf-s3 deploy-lambda deploy-api-gateway deploy-dynamodb