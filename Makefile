TF_DIR=platform-terraform
APP_DIR=app-cicd

.PHONY: apply destroy lint test

apply:
	cd $(TF_DIR) && terraform init && terraform apply

destroy:
	cd $(TF_DIR) && terraform destroy

lint:
	terraform fmt -check ./$(TF_DIR)
	cd $(APP_DIR) && mvn -B -DskipTests checkstyle:check spotbugs:check

test:
	cd $(APP_DIR) && mvn -B test
