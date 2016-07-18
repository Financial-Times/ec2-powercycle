FROM alpine

RUN apk --update add py-pip gcc python-dev libffi-dev openssl-dev build-base bash jq util-linux curl git zip \
 && pip install ansible boto3 awscli requests

ADD *.sh /

CMD /bin/bash package.sh && /bin/bash lambda-deploy-latest.sh && /bin/bash lambda-invoke-function.sh ec2-powercycle DryRun
#CMD /bin/bash
