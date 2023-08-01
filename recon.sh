#!/bin/bash


main(){

port_Shot(){
  target=$1
  echo -e "${light_yellow} [+] Scaning for open ports ${clr}"
  rustscan -a $target -p 20,21,22,23,25,53,80,110,111,135,139,143,443,445,993,995,1723,3306,3389,5900,8080 -- -sC -sV -oA $pwd/rootDomains/$domain/nmap
  sleep 2
  echo -e "${light_yellow} [+] Taking screen shots of open ports ${clr}"
  gowitness --disable-db nmap -f $pwd/rootDomains/$domain/nmap.xml -P screenshots
  sleep 1
} 

subdomains(){
  domain="$1"
  if [ ! -d "rootDomains" ]; then
		mkdir -p rootDomains/$domain/screenshots
    

		pwd=$(pwd)
		echo -e "${cyan}[+] Gathering subdomains${clr}" 
    echo -e "${turquoise}[+] Trying to collect subdomains from crtsh${clr}" 
		crtsh -d $domain >> $pwd/rootDomains/$domain/crtsh.txt 
    if [ ! -f "$pwd/rootDomains/$domain/crtsh.txt" ]; then 
    echo -e "${light_red}[!] Error - Failed to collect subdomains from crtsh${clr}"
    fi
		sleep 1

    echo -e "${turquoise}[+] Trying to collect subdomains from assetfinder${clr}" 
		assetfinder --subs-only $domain >> $pwd/rootDomains/$domain/assetfinder.txt 
    if [ ! -f "$pwd/rootDomains/$domain/assetfinder.txt" ]; then 
    echo -e "${light_red}[!] Error - Failed to collect subdomains from assetfinder${clr}"
    fi
    
    echo -e "${turquoise}[+] Trying to collect subdomains from sublist3r${clr}"
    sublist3r -d $domain -o $pwd/rootDomains/$domain/sublister.txt > /dev/null 2>&1
    if [ ! -f "$pwd/rootDomains/$domain/sublister.txt" ]; then 
    echo -e "${light_red}[!] Error - Failed to collect subdomains from sublist3r${clr}"
    fi 

    echo -e "${turquoise}[+] Trying to collect subdomains from findomain${clr}"
		findomain -t $domain -u $pwd/rootDomains/$domain/findomain.txt > /dev/null 2>&1 
    if [ ! -f "$pwd/rootDomains/$domain/findomain.txt" ]; then 
    echo -e "${light_red}[!] Error - Failed to collect subdomains from finddomain${clr}"
    fi
		sleep 1

    echo -e "${turquoise}[+] Trying to collect subdomains from amass${clr}"       
    #amass enum -d $domain -o $pwd/rootDomains/$domain/amass.txt > /dev/null 2>&1 
    if [ ! -f "$pwd/rootDomains/$domain/amass.txt" ]; then 
    echo -e "${light_red}[!] Error - Failed to collect subdomains from amass${clr}"
    fi
	

    

		echo -e "${turquoise}[+] Doing the bash magic${clr}"
		cat $pwd/rootDomains/$domain/amass.txt $pwd/rootDomains/$domain/assetfinder.txt $pwd/rootDomains/$domain/crtsh.txt $pwd/rootDomains/$domain/findomain.txt $pwd/rootDomains/$domain/sublister.txt >> $pwd/rootDomains/$domain/all.txt
    cat $pwd/rootDomains/$domain/all.txt | grep "$domain" >> $pwd/rootDomains/$domain/allsubs.txt
		sort -u $pwd/rootDomains/$domain/allsubs.txt >> $pwd/rootDomains/$domain/sorted-subs.txt
		
    if [ -f "$pwd/rootDomains/$domain/sorted-subs.txt" ]; then 
    echo -e "${light_yellow}[+] Successfully Combained and Sorted the result${clr}"
    else
    echo -e "${light_red}[!] Error - Failed to sort the subdomains${clr}"
    exit 1
    fi

		

		echo -e "${green}[+] Checking alive targets ${clr}"
    touch $pwd/rootDomains/$domain/alive.txt
    output=$(cat $pwd/rootDomains/$domain/sorted-subs.txt | anew -d $pwd/rootDomains/$domain/unique-sub.txt)
    echo $output
    echo "this is the output"
		cat $pwd/rootDomains/$domain/sorted-subs.txt | anew $pwd/rootDomains/$domain/unique-sub.txt
    sleep 2
    cat $pwd/rootDomains/$domain/unique-sub.txt | httprobe -prefer-https | sed 's/https\?:\/\///' | sort -u | tee -a $pwd/rootDomains/$domain/alive.txt
    sleep 1
    echo $ouput | httpx -sc -td -title -server | tee -a $pwd/rootDomains/$domain/httpx.txt
    # sleep 2
    port_Shot $output
    sleep 1
    if [ ! -f "$pwd/rootDomains/$domain/alive.txt" ]; then 
    echo "${light_yellow}[+] So far everything G00D ${clr}"
    else
    echo "${red}[!] Failure - Recon interrupted ${clr}"
    fi

  fi
}




read_File(){
# Check if a filename was provided as an argument
  if [ $# -ne 1 ]; then
    echo -e "[-] Usage: $0 -f filename -r"
    exit 1
  fi

  filename="$1"
  total_domains=$(wc -l < "$filename")


  # Check if the file exists and is readable
  if [ ! -r "$filename" ]; then
    echo -e "${red}[!] Error: file '$filename' does not exist or is not readable${clr}"
    exit 1
  fi
  current_domain=1
  # Read the file line by line and output each domain
  while read -r domain; do
    echo -e "${green}Target: [$current_domain/$total_domains] - $domain ${clr}"
    subdomains $domain
    ((current_domain++))
  done < "$filename"
}





options(){    
while getopts ":d:f:rp" opt; do
  case $opt in
    d)

      domain="$OPTARG"
      ;;
    f)
      file="$OPTARG"
      ;;
    r)
      recon=true
      ;;
    p)
      port_scan=true
      ;;
    \?)
      echo "${blue}Invalid Option: -$OPTARG ${clr}" >&2
      exit 1
      ;;
    :)
      echo -e "${blue}Option -$OPTARG requires an argument.${clr}" >&2
      exit 1
      ;;
  esac
done

if [ -n "$domain" ] && [ -n "$file" ]; then
  echo -e "${yellow} [!] Error: cannot specify both domain and file ${clr}" >&2
  exit 1
fi

if [ -z "$domain" ] && [ -z "$file" ]; then
  echo -e "${yellow}[Error: must specify either domain or file ${clr}" >&2
  exit 1
fi

if [ -n "$domain" ] && [ "$recon" = true ]; then
  subdomains $domain
fi

if [ -n "$file" ] && [ "$recon" = true ]; then
  read_File $file
fi

# if [ "$recon" = true ]; then
#   echo "Performing recon..."
#   # Add your recon commands here
# fi

if [ "$port_scan" = true ]; then
  echo -e  "${light_red}[!] Under development"
  
fi
}

colors(){
  red='\033[0;91m'
  green='\033[0;92m'
  yellow='\033[0;93m'
  blue='\033[0;94m'
  magenta='\033[0;95m'
  cyan='\033[0;96m'
  pink='\033[0;38;5;213m'
  purple='\033[0;38;5;141m'
  turquoise='\033[0;38;5;51m'
  clr='\033[0m'
  light_yellow='\e[38;5;229m'
  orange='\e[38;5;208m'
  light_red='\e[38;5;203m'
  clr='\e[0m'
}

colors
options $@
}


main $@



