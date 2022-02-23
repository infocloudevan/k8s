# fix-whois

Rescore IP threats with missing WHOIS data

## Steps

1. Run `get-whois.sh` against the SAAS database to get IDs of threats with missing whois info

    % kubectl cp get-whois.sh <saas-pod>:/var/tmp
    % kubectl exec <saas-pod> -it -- /var/tmp/get-whois.sh <saas-host> <port> <db> <username>
    % kubectl cp <saas-pod>:/no_whois.csv . 

2. Run `flush-whois.sh` against the D3OC database to clear log tables

    % kubectl cp flush-whois.sh <d3pc-pod>:/var/tmp
    % kubectl cp no_whois.csv <d3oc-pod>:/
    % kubectl exec <d3oc-pod> -it -- /var/tmp/flush-whois.sh <host> <port> <db> <username>    
    % kubectl exec <d3oc-pod> -it -- telnet queue 11300
    delete all
    quit

3. Run `rescore` to submit scoring jobs to coach

    % kubectl cp <rescore-path>/rescore <saas-pod>:/var/tmp
    % kubectl cp no_whois.csv <saas-pod>:/
    % kubectl exec <saas-pod> -- /var/tmp/rescore --input-file /no_whois.csv <coach-endpoint-url>
