#!/bin/bash
# jmu 30/Nov/2019
# this script needs jq (yum install jq, brew install jq, ....)
#
compartment=$1
bucket=$2
#
usage(){
    echo "Usage:"
    echo "      ./auditoser.sh compartmentid bucketname"
    echo "Example:"
    echo "      ./auditoser.sh ocid1.compartment.oc1..aaaaaaaa3sz43qrfhsjmbibsrc6e7c2ftlt53gfnzifvlow2yoz7hk3ni2jq AUDIT"
}
#
if [[ "$#" -ne 2 ]]; then
    echo
    echo "Wrong number of arguments passed!"
    echo
    usage
    exit
fi
os=$(uname -a)
# the tool archives the day before
if echo "$os" | grep -q "Linux"; then
    # linuxlike
    thedayafterday=$(date --date='-1 day' "+%Y-%m-%d")
    initial="${thedayafterday}T00:00:00.000Z"
    final="${thedayafterday}T23:59:59.999Z";
elif echo "$os" | grep -q "Darwin"; then
    # mac
    thedayafterday=$(date -v-1d "+%Y-%m-%d")
    initial="${thedayafterday}T00:00:00.000Z"
    final="${thedayafterday}T23:59:59.999Z"
else
    #
    echo "I haven't been instructed by the programmer how to deal with date in this platform"
    echo ":-("
    echo ":-)"
    exit -1
fi
#
echo "OCI Audit to Object Storage Archiver"
echo "Initial audit date: ${initial}"
echo "Final audit date: ${final}"
file=audit-${initial}-${final}
# empty file
echo "" > ${file}
# the first command to execute, results come paginated
command="oci audit event list --compartment-id ${compartment} --start-time ${initial} --end-time ${final}"
while :
do
    #
    result=`$command`
    # this variable stores the records
    records=`echo $result | jq '.data'`
    echo ${records} >> ${file}
    # this variable stores the next page of results
    nextpage=`echo $result | jq '.["opc-next-page"]'`
    nextpage=$(eval echo $nextpage)
    #echo ${nextpage}
    if [[ "$nextpage" == "" ]]; then
        # no more pages
        break
    fi
    # recurring calls with page parameter
    command="oci audit event list --compartment-id ${compartment} --start-time ${initial} --end-time ${final} --page ${nextpage}"
    #echo ${command}
    # don't wanna fry the cpu
    sleep 1
done
# compressing
zipfile="${file}.gz"
gzip -f "${file}"
# uploading to object storage overwriting if file already exists
oci os object put -bn ${bucket} --file ${zipfile} --force --output table
ls -alt
rm ${zipfile}
echo "goodbye!"
