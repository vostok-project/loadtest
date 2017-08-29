.PHONY: fire pull
.PHONY: run-java-gate run-java-consumer kill-java build-java
.PHONY: run-dotnet-gate publish-dotnet-gate run-dotnet-consumer publish-dotnet-consumer run-dotnet-consumer2 publish-dotnet-consumer2

MAXRPS=1000
TESTDUR=1200
EVENTSIZE=10
GATEPORT=8888
LANG=Java
REV=$(shell git rev-parse --short HEAD)

JAVA_COMMON_PARAMS = -Xms16g -Xmx16g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -jar ./target/uber-kload-1.0-SNAPSHOT.jar

run-java-gate: build-java
	java ${JAVA_COMMON_PARAMS} gate

run-java-consumer: build-java
	java ${JAVA_COMMON_PARAMS} consumer

kill-java:
	pgrep java | awk '{system("kill -9 "$$1)}'

build-java: pull
	mvn clean package

run-dotnet-gate: publish-dotnet-gate
	dotnet/KafkaLoadService.Core/bin/Debug/netcoreapp2.0/rhel-x64/publish/KafkaLoadService.Core

publish-dotnet-gate: pull
	cd dotnet/KafkaLoadService.Core && dotnet publish -r rhel-x64
	cp /usr/local/lib/librdkafka*.so dotnet/KafkaLoadService.Core/bin/Debug/netcoreapp2.0/rhel-x64/publish/

run-dotnet-consumer: publish-dotnet-consumer
	dotnet/ConsumerTest/bin/Debug/netcoreapp2.0/rhel-x64/publish/ConsumerTest

publish-dotnet-consumer: pull
	cd dotnet/ConsumerTest && dotnet publish -r rhel-x64
	cp /usr/local/lib/librdkafka*.so dotnet/ConsumerTest/bin/Debug/netcoreapp2.0/rhel-x64/publish/

run-dotnet-consumer2: publish-dotnet-consumer2
	dotnet/ConsumerTest2/bin/netcoreapp2.0/rhel-x64/publish/ConsumerTest2

publish-dotnet-consumer2: pull
	cd dotnet/ConsumerTest2 && dotnet publish -r rhel-x64
	cp /usr/local/lib/librdkafka*.so dotnet/ConsumerTest2/bin/netcoreapp2.0/rhel-x64/publish/

fire: pull
	echo "[phantom]"                                                                              >  autogenerated.ini
	echo "address = edi18:${GATEPORT}"                                                            >> autogenerated.ini
	echo "rps_schedule = line(1, ${MAXRPS}, 60s) const(${MAXRPS}, ${TESTDUR}s)"                   >> autogenerated.ini
	echo "instances = 10000"                                                                      >> autogenerated.ini
	echo "header_http = 1.1"                                                                      >> autogenerated.ini
	echo "headers = [Host: edi18]"                                                                >> autogenerated.ini
	echo "uris = /kload${EVENTSIZE}"                                                              >> autogenerated.ini
	echo "[telegraf]"                                                                             >> autogenerated.ini
	echo "config = monitoring.xml"                                                                >> autogenerated.ini
	echo "[overload]"                                                                             >> autogenerated.ini
	echo "token_file = token.txt"                                                                 >> autogenerated.ini
	echo "ver = ${REV}"                                                                           >> autogenerated.ini
	echo "job_name = Airlock-${LANG} /kload${EVENTSIZE} version ${REV}"                           >> autogenerated.ini
	echo "job_dsc = line(1, ${MAXRPS}, 60s) const(${MAXRPS}, ${TESTDUR}s)"                        >> autogenerated.ini
	echo "<Monitoring>"                                                                           >  monitoring.xml
	for host in edi18 icat-test01 icat-test02 icat-test03 ; do \
		echo "  <Host address=\"$$host\" comment=\"$$host\">"                                     >> monitoring.xml ; \
		echo "    <CPU />"                                                                        >> monitoring.xml ; \
		echo "    <Memory />"                                                                     >> monitoring.xml ; \
		echo "    <Disk devices='[\"sda3\",\"sda4\"]'></Disk>"                                    >> monitoring.xml ; \
		echo "    <Net interfaces='[\"team0\"]'></Net>"                                           >> monitoring.xml ; \
		echo "    <Netstat />"                                                                    >> monitoring.xml ; \
		echo "  </Host>"                                                                          >> monitoring.xml ; \
	done
	for host in edi18 icat-test04 icat-test05 ; do \
		echo "  <Host address=\"$$host\" interval=\"3\" comment=\"$$host\">"                                     >> monitoring.xml ; \
		echo "    <Custom diff=\"1\" measure=\"call\" label=\"Producer Throughput\">curl -s 'http://$$host:8888/th'</Custom>" >> monitoring.xml ; \
		echo "    <Custom diff=\"1\" measure=\"call\" label=\"Producer MTT\">curl -s 'http://$$host:8888/mtt'</Custom>" >> monitoring.xml ; \
		echo "    <Custom diff=\"1\" measure=\"call\" label=\"Consumer Throughput\">curl -s 'http://$$host:8889/th'</Custom>" >> monitoring.xml ; \
		echo "    <Custom diff=\"1\" measure=\"call\" label=\"Consumer MTT\">curl -s 'http://$$host:8889/mtt'</Custom>" >> monitoring.xml ; \
		echo "  </Host>"                                                                          >> monitoring.xml ; \
	done
	echo "</Monitoring>"                                                                          >> monitoring.xml
	yandex-tank -c autogenerated.ini

pull:
	git pull