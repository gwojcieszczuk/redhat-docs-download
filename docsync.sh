#!/bin/bash


website=https://docs.redhat.com/
docdir="."


function listProducts {

	products=($(curl $website/en/products/ 2> /dev/null | sed 's/href=/\n&/g' | \
		grep 'href="/en/documentation/' | awk -F/ '{ print $4 }' | sort | uniq))

	for i in ${products[@]}
	do
		echo "  - $i"
	done
}

function checkIfProductExists {
	products=($(curl $website/en/products/ 2> /dev/null | sed 's/href=/\n&/g' | \
		grep 'href="/en/documentation/' | awk -F/ '{ print $4 }' | sort | uniq))
	prd=$1
	result=0
	for i in ${products[@]}
	do
		if [ "$prd" == "$i" ]; then
			result=1
			break
		fi
	done
	echo $result
	
}

function getHelp {
	cat <<EOL

	Documents are downloaded to current/working directory.

	$0 -h                             Show this help
	$0 -l                             List all products
	$0 -d all                         Download documentation for all products
	$0 -d red_hat_enterprise_linux    Download documentation for <red_hat_enterprise_linux>  

EOL
}


function downloadDocs {

	for product in ${products[@]}
	do
		link=$(curl $website/en/documentation/$product/ 2> /dev/null | sed 's@.*url=@@' | sed 's@".*@@')
		curl $website/$link > tmp.html 2> /dev/null
		versions=($(xmllint --nonet --nowarning --html --nowrap --recover --xpath \
			'//select[@id="product_version"]/option/text()'  tmp.html 2> /dev/null))
		rm -f tmp.html
		for i in ${versions[@]}
		do
			urls=($(curl $website/en/documentation/$product/$i 2> /dev/null grep href | \
				grep documentation | sed 's@\\r\\n@,@g' | tr ',' '\n' | \
				sed 's@^"@@' | grep '^/documentation'  | sed 's@\*.*@@'  | \
				grep -w html | sed 's@html@pdf@' | sed 's@"$@@'))
			for a in ${urls[@]}
			do
				thisdocdir=$docdir/$product/$i
				if [ ! -d "$thisdocdir" ]; then
					mkdir -p "${thisdocdir}"
					if [ $? -ne 0 ]; then
						echo "Unable to create $thisdocdir. Aborting"
						exit 5
					fi
				fi

				filename="$thisdocdir/${product}-${i}-$(basename $a).pdf"
				echo -en "  * Downloading $(basename $filename): "
				if [ ! -f "$filename" ]; then
			     		wget $website/en$a -O "$thisdocdir"/${product}-${i}-$(basename $a).pdf &> /dev/null
			     		if [ $? -eq 0 ]; then
				     		echo -en "OK\n"
					else
						echo -en "FAILED\n"
			     		fi
			     		stat -c %b "$filename" | grep -w 0 &> /dev/null
			     		if [ $? -eq 0 ]; then
				     		rm -f "$filename"
			     		fi

				else
			     		echo -en "already downloaded\n"
				fi
			done
		done

	done

}

if [ ! $1 ]; then
	echo "No option specified."
	exit 2
fi

while getopts d:lh opt
do
	case ${opt} in
		l)
			echo "Available Products:"
			listProducts
			exit 0
			;;
		d)
			if [ "$OPTARG" == "all" ]; then

				products=($(curl $website/en/products/ 2> /dev/null | sed 's/href=/\n&/g' | \
					grep 'href="/en/documentation/' | awk -F/ '{ print $4 }' | sort | uniq))
				echo "Downloading documentation for all products"	
				downloadDocs
			else
				isThereAnythingToDownload="$(checkIfProductExists "$OPTARG")"
				if [ "$isThereAnythingToDownload" == "0" ]; then
					echo "No such product: $OPTARG"
					exit 4
				fi
				echo "Downloading documentation for <$OPTARG>"
				products=($OPTARG)
				downloadDocs
			fi
			;;
		h)
			getHelp
			;;
	esac
done

