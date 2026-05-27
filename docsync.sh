#!/usr/bin/env bash


website=https://docs.redhat.com/
docdir="."
ostype="$(uname -s)"

function toolCheck {
        tools=(curl grep sed sort uniq awk xmllint)
        for i in ${tools[@]}
        do
                $i --help &> /dev/null
                if [ $? -eq 127 ]; then
                        echo "Tool $i not available. Aborting."
                        exit 6
                fi

        done

}

toolCheck


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

function listVersions {
	product=$1
	link=$(curl $website/en/documentation/$product/ 2> /dev/null | sed 's@.*url=@@' | sed 's@".*@@')
	curl $website/$link > tmp.html 2> /dev/null
        #versions=($(xmllint --nonet --nowarning --html --nowrap --recover --xpath \
        #       '//select[@id="product_version"]/option/text()' tmp.html 2> /dev/null))
        # Looks like some newer versions of xmllint don't support --nowrap option.
        #
        versions=($(xmllint --nonet --nowarning --html --recover --xpath \
                '//select[@id="product_version"]/option/text()' tmp.html 2> /dev/null))

	rm -f tmp.html
	for i in ${versions[@]}
	do
		echo "  - $i"
	done
}

function getHelp {
	cat <<EOL

	Documents are downloaded to current/working directory.

	$0 -h                                                     Show this help
	$0 -l                                                     List all products
	$0 -d red_hat_enterprise_linux -l                         List versions for a product
	$0 -d all                                                 Download documentation for all products
	$0 -d red_hat_enterprise_linux                            Download documentation for all versions
	$0 -d red_hat_openshift_ai_self-managed -v 2.25           Download documentation for a specific version

EOL
}


function downloadDocs {

	for product in ${products[@]}
	do
		link=$(curl $website/en/documentation/$product/ 2> /dev/null | sed 's@.*url=@@' | sed 's@".*@@')
		curl $website/$link > tmp.html 2> /dev/null
		versions=($(xmllint --nonet --nowarning --html --recover --xpath \
			'//select[@id="product_version"]/option/text()'  tmp.html 2> /dev/null))
		rm -f tmp.html
		for i in ${versions[@]}
		do
			if [ -n "$version" ] && [ "$i" != "$version" ]; then
				continue
			fi
			urls=($(curl $website/en/documentation/$product/$i 2> /dev/null grep href | \
				grep documentation | sed 's@\\r\\n@,@g' | tr ',' '\n' | \
				sed 's@^"@@' | grep "^/documentation/$product/$i/"  | sed 's@\*.*@@'  | \
				grep -w html | sed 's@html@pdf@' | sed 's@"$@@' | grep -v '/index[/]*$'))
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
						actual_pdf_url=$(curl -s "$website/en$a/index" 2>/dev/null | \
							grep -o '"[^"]*\.pdf"' | tr -d '"' | head -1)
						if [ -z "$actual_pdf_url" ]; then
							echo -en "FAILED (PDF URL not found)\n"
						else
							curl "$actual_pdf_url" --output "$filename" &> /dev/null
							if [ $? -eq 0 ]; then
								echo -en "OK\n"
								if [ "$ostype" == "Darwin" ]; then
									stat -f %b "$filename" | grep -w 0 &> /dev/null
								else
									stat -c %b "$filename" | grep -w 0 &> /dev/null
								fi
								if [ $? -eq 0 ]; then
									rm -f "$filename"
								fi
							else
								echo -en "FAILED\n"
								rm -f "$filename"
							fi
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

action=""
product_arg=""
version=""

while getopts d:v:lh opt
do
	case ${opt} in
		l) action="list" ;;
		d) product_arg="$OPTARG" ;;
		v) version="$OPTARG" ;;
		h) action="help" ;;
		*) action="help" ;;
	esac
done

# Default to "download" if a product was given and no conflicting action set
if [ -n "$product_arg" ] && [ "$action" != "help" ]; then
	if [ "$action" == "list" ]; then
		action="list_versions"
	else
		action="download"
	fi
fi

case "$action" in
	list)
		echo "Available Products:"
		listProducts
		exit 0
		;;
	list_versions)
		isThereAnythingToDownload="$(checkIfProductExists "$product_arg")"
		if [ "$isThereAnythingToDownload" == "0" ]; then
			echo "No such product: $product_arg"
			exit 4
		fi
		echo "Available versions for <$product_arg>:"
		listVersions "$product_arg"
		exit 0
		;;
	download)
		if [ "$product_arg" == "all" ]; then
			if [ -n "$version" ]; then
				echo "Cannot specify a version with 'all'. Please specify a single product."
				exit 3
			fi
			products=($(curl $website/en/products/ 2> /dev/null | sed 's/href=/\n&/g' | \
				grep 'href="/en/documentation/' | awk -F/ '{ print $4 }' | sort | uniq))
			echo "Downloading documentation for all products"
			downloadDocs
		else
			isThereAnythingToDownload="$(checkIfProductExists "$product_arg")"
			if [ "$isThereAnythingToDownload" == "0" ]; then
				echo "No such product: $product_arg"
				exit 4
			fi
			if [ -n "$version" ]; then
				echo "Downloading documentation for <$product_arg> version $version"
			else
				echo "Downloading documentation for <$product_arg>"
			fi
			products=($product_arg)
			downloadDocs
			if [ -n "$version" ] && [ ! -d "$docdir/$product_arg/$version" ]; then
				echo "Warning: version '$version' was not found for product '$product_arg'. Use -d $product_arg -l to list available versions."
			fi
		fi
		;;
	help|*)
		getHelp
		;;
esac

