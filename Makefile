VERSION ?= 0.1.0
APPLICATION ?= jenkins-pipelines
BUILD_DIR ?= bin

all: $(BUILD_DIR)

$(BUILD_DIR):
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -a -installsuffix cgo -o $(BUILD_DIR)/$(APPLICATION) .

.PHONY: docker-image
docker-image: clean $(BUILD_DIR)
	docker build -t jenkins-pipelines:$(VERSION) .

.PHONY: clean
clean:
	-rm -r bin

.PHONY: test
test:
	go test -cover -v .

.PHONY: docker-push
docker-push:
ifndef REGISTRY
	@echo 'REGISTRY not defined'
	@exit 1
endif
	docker tag jenkins-pipelines:$(VERSION) $(REGISTRY)/jenkins-pipelines:$(VERSION)
	docker push $(REGISTRY)/jenkins-pipelines:$(VERSION)
	docker rmi $(REGISTRY)/jenkins-pipelines:$(VERSION)


