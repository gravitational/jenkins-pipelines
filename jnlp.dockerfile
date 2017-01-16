FROM openjdk:8-jdk

ENV HOME /home/jenkins
ENV JNLP_PROTOCOL_OPTS -Dorg.jenkinsci.remoting.engine.JnlpProtocol3.disabled=true

ARG VERSION=2.62

RUN curl --create-dirs -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar

RUN mkdir /home/jenkins
RUN mkdir /home/jenkins/.jenkins
WORKDIR /home/jenkins

COPY jenkins-slave /usr/local/bin/jenkins-slave
RUN chmod a+x /usr/local/bin/jenkins-slave

ENTRYPOINT ["jenkins-slave"]
