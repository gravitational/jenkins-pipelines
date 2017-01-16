#!/usr/bin/env groovy

properties([
    parameters([
        string(defaultValue: 'jenkinsci/jnlp-slave:2.62-alpine', description: '', name: 'JNLP_IMAGE'),
        string(defaultValue: 'jenkins-ns', description: '', name: 'K8S_NAMESPACE'),
        string(defaultValue: 'quay.io', description: '', name: 'REGISTRY_SERVER'),
        string(defaultValue: 'eric-cartman', description: '', name: 'REGISTRY_USERNAME'),
        password(defaultValue: 'badkitty', description: '', name: 'REGISTRY_PASSWORD'),
        string(defaultValue: 'quay.io/eric-cartman', description: '', name: 'REGISTRY_REPO'),
        string(defaultValue: '1.12.6', description: '', name: 'DOCKER_VERSION'),
        string(defaultValue: 'v2.1.3', description: '', name: 'HELM_VERSION'),
        string(defaultValue: 'v1.4.6', description: '', name: 'KUBECTL_VERSION')
    ]),
    pipelineTriggers([])
])

def srcdir = 'github.com/gravitational/jenkins-pipelines'


podTemplate(label: 'build-pod',
    containers: [
        containerTemplate(name: 'jnlp', image: JNLP_IMAGE, args: '${computer.jnlpmac} ${computer.name}'),
        containerTemplate(name: 'golang', image: 'golang:1.7', ttyEnabled: true, command: 'cat')
    ],
    volumes: [
        hostPathVolume(hostPath: '/var/run/docker.sock', mountPath: '/var/run/docker.sock')
    ]
) {
    node('build-pod') {
        container('golang') {
            stage('Checkout') {
                checkout scm
            }

            stage('Prepare') {
                timeout(time: 5, unit: 'MINUTES') {
                    // Install Docker CLI
                    sh """
                    curl -Lo /tmp/docker.tgz https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz
                    mkdir /tmp/docker
                    tar -xf /tmp/docker.tgz -C /tmp/docker
                    find /tmp/docker -type f -executable -exec mv {} /usr/local/bin/ \\;
                    """

                    // Install Helm
                    sh """
                    curl -Lo /tmp/helm.tar.gz https://kubernetes-helm.storage.googleapis.com/helm-${HELM_VERSION}-linux-amd64.tar.gz
                    tar -zxvf /tmp/helm.tar.gz -C /tmp
                    mv /tmp/linux-amd64/helm /usr/local/bin/helm
                    chmod +x /usr/local/bin/helm
                    """

                    // Install Kubectl
                    sh """
                    curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
                    chmod a+x /usr/local/bin/kubectl
                    """

                    // Move source to GOPATH to avoid problems with go toolkit
                    sh """
                    mkdir -p \$GOPATH/src/${srcdir}
                    ln -s \$(realpath .) \$GOPATH/src/${srcdir}
                    """
                }
            }

            stage('Build') {
                timeout(time: 5, unit: 'MINUTES') {
                    sh """
                    cd \$GOPATH/src/${srcdir}
                    make docker-image
                    """
                }
            }

            stage('Test') {
                timeout(time: 5, unit: 'MINUTES') {
                    sh """
                    cd \$GOPATH/src/${srcdir}
                    make test
                    """
                }
            }

            stage('Integration test') {
                try {
                    timeout(time: 30, unit: 'MINUTES') {
                        sh """
                        docker login --username='${REGISTRY_USERNAME}' --password='${REGISTRY_PASSWORD}' '${REGISTRY_SERVER}'
                        kubectl create namespace '${K8S_NAMESPACE}'
                        cd \$GOPATH/src/${srcdir}
                        make docker-push REGISTRY='${REGISTRY_REPO}'
                        helm init --client-only
                        """

                        // Helm requires kubeconfig, but we have token-based serviceaccount, so let's make kubeconfig out of it
                        def token = new File('/run/secrets/kubernetes.io/serviceaccount/token').text
                        def kubeconfig = """apiVersion: v1
clusters:
- cluster:
    certificate-authority: /run/secrets/kubernetes.io/serviceaccount/ca.crt
    server: https://${ -> env.KUBERNETES_SERVICE_HOST }:${ -> env.KUBERNETES_SERVICE_PORT }
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    token: ${token}
"""
                        def f = new File("${ -> env.HOME }/.kube/config")
                        f.append(kubeconfig)
                        sh "helm install --namespace='${K8S_NAMESPACE}' ./chart/webserver"

                        waitForAllPodsRunning(K8S_NAMESPACE)
                        waitForAllServicesRunning(K8S_NAMESPACE)
                    }
                } finally {
                    sh "kubectl delete namespace '${K8S_NAMESPACE}'"
                }
            }
        }
    }
}

def waitForAllPodsRunning(String namespace) {
    timeout(KUBERNETES_RESOURCE_INIT_TIMEOUT) {
        while (true) {
            podsStatus = sh(returnStdout: true, script: "kubectl --namespace='${namespace}' get pods --no-headers").trim()
            def notRunning = podsStatus.readLines().findAll { line -> !line.contains('Running') }
            if (notRunning.isEmpty()) {
                echo 'All pods are running'
                break
            }
            sh "kubectl --namespace='${namespace}' get pods"
            sleep 10
        }
    }
}

def waitForAllServicesRunning(String namespace) {
    timeout(KUBERNETES_RESOURCE_INIT_TIMEOUT) {
        while (true) {
            servicesStatus = sh(returnStdout: true, script: "kubectl --namespace='${namespace}' get services --no-headers").trim()
            def notRunning = servicesStatus.readLines().findAll { line -> line.contains('pending') }
            if (notRunning.isEmpty()) {
                echo 'All pods are running'
                break
            }
            sh "kubectl --namespace='${namespace}' get services"
            sleep 10
        }
    }
}

