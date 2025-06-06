#!/bin/bash

# Script de instalação automática do Traccar com MariaDB
# Versão do Traccar: 6.6 (verificar atualizações em https://www.traccar.org/download/)

# Verificar se é root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script deve ser executado como root ou com sudo." >&2
    exit 1
fi

# 1. Atualizar o sistema
echo "Atualizando o sistema..."
apt update && apt upgrade -y

# 2. Instalar o MariaDB
echo "Instalando o MariaDB..."
apt install mariadb-server mariadb-client -y

# Iniciar e habilitar o serviço
systemctl start mariadb
systemctl enable mariadb

# Configurar segurança inicial automaticamente
echo "Configurando segurança do MariaDB..."
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Switch to unix_socket authentication\"
send \"n\r\"
expect \"Change the root password?\"
send \"y\r\"
expect \"New password:\"
send \"\r\"
expect \"Re-enter new password:\"
send \"\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL"

# 3. Criar banco de dados e usuário para o Traccar
echo "Criando banco de dados e usuário para o Traccar..."

# Gerar senha aleatória para o usuário traccar
DB_PASSWORD=$(openssl rand -base64 12)

mysql -u root <<EOF
CREATE DATABASE traccar CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER 'traccar'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON traccar.* TO 'traccar'@'localhost';
FLUSH PRIVILEGES;
EOF

# 4. Baixar e instalar o Traccar
echo "Baixando e instalando o Traccar..."
TRACCAR_VERSION="6.6"
wget https://github.com/traccar/traccar/releases/download/v$TRACCAR_VERSION/traccar-linux-64-$TRACCAR_VERSION.zip -O traccar.zip

apt install unzip -y
unzip traccar.zip
chmod +x traccar.run
./traccar.run

# 5. Configurar o Traccar para usar o MariaDB
echo "Configurando o Traccar para usar o MariaDB..."

# Criar backup do arquivo de configuração original
cp /opt/traccar/conf/traccar.xml /opt/traccar/conf/traccar.xml.bak

# Configurar arquivo traccar.xml
cat > /opt/traccar/conf/traccar.xml <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE properties SYSTEM 'http://java.sun.com/dtd/properties.dtd'>
<properties>
    <entry key='config.default'>./conf/default.xml</entry>
    <entry key='web.port'>8082</entry>
    <entry key='web.path'>./web</entry>
    <entry key='web.type'>auto</entry>
    <entry key='web.application'>./traccar-web.war</entry>
    <entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
    <entry key='database.url'>jdbc:mysql://localhost:3306/traccar?serverTimezone=UTC</entry>
    <entry key='database.user'>traccar</entry>
    <entry key='database.password'>$DB_PASSWORD</entry>
    <entry key='geocoder.enable'>false</entry>
    <entry key='logger.enable'>true</entry>
    <entry key='logger.level'>all</entry>
    <entry key='logger.file'>./logs/tracker-server.log</entry>
</properties>
EOF

# 6. Baixar o driver JDBC do MySQL/MariaDB
echo "Baixando o driver JDBC..."
wget https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.3.0/mysql-connector-j-8.3.0.jar -O mysql-connector-j.jar
mv mysql-connector-j.jar /opt/traccar/lib/

# 7. Reiniciar o Traccar
echo "Reiniciando o serviço Traccar..."
systemctl restart traccar

# Mostrar informações de instalação
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================"
echo "Instalação do Traccar concluída com sucesso!"
echo "============================================"
echo ""
echo "Acesse o sistema em: http://$IP_ADDRESS:8082"
echo ""
echo "Credenciais do banco de dados:"
echo "Usuário: traccar"
echo "Senha: $DB_PASSWORD"
echo ""
echo "Esta senha foi gerada automaticamente. Salve-a em um local seguro."
echo "============================================"

exit 0