This script is a rough draft for installation of a TAK server, for ATAK.

ATAK can be researched here: 
https://tak.gov/

Use this script at your own discretion.

Requirements

    Debian 12 (that what I use), Ubuntu, RHEL, CentOS
    OpenLDAP server (slapd preferred)

Steps

    Install slapd server and LDAP tools:

    apt install -y slapd ldap-utils

    Download enhanced version of LDAP schema:

    wget https://github.com/palw3ey/rfc2307bis/releases/download/latest/rfc2307bis.ldif -O /etc/ldap/schema/rfc2307bis.ldif

    Update slapd configuration to use new schema:

    sed -i 's|^include: file:///etc/ldap/schema/nis.ldif|#&\ninclude: file:///etc/ldap/schema/rfc2307bis.ldif|' /usr/share/slapd/slapd.init.ldif

    Restart & reconfigure LDAP server:

    systemctl restart slapd

    dpkg-reconfigure slapd

In this step enter:

    administrator's password (eg. abcd1234)
    organization name (eg. TAKSERVER)
    domain name (eg. takserver.local)

    The magic starts here :)

    create organizational units for users (ou=people,dc=takserver,dc=local) and groups (ou=groups,dc=takserver,dc=local)

    ldapadd -x -D cn=admin,dc=takserver,dc=local -w -f add_nodes.ldif

    enable logging (I don't need it in production environment - just for finding problems)

    ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f logging.ldif

    enable memberof functionality in LDAP server

    ldapadd -Q -Y EXTERNAL -H ldapi:/// -f membersof_config.ldif

    ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f refint1.ldif

    ldapadd -Q -Y EXTERNAL -H ldapi:/// -f refint2.ldif

    modify LDAP schema to support takCallsign, takColor and takRole attributes

    ldapadd -Q -Y EXTERNAL -H ldapi:/// -f mod_schema.ldif

    add some users and groups for tests. Default username is abcd1234. You can change it with slapdpasswd -s command.

    ldapadd -x -D cn=admin,dc=takserver,dc=local -w -f add_user.ldif

    ldapadd -x -D cn=admin,dc=takserver,dc=local -w -f add_group.ldif






Link to installation of a Wireguard VPN (All credit goes to Nyr):
https://github.com/Nyr/wireguard-install/blob/master/wireguard-install.sh
