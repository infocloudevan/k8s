## Database Stuff

### Setup

```
insert into account_type_codes (account_type_code, account_type_description) values ('PERSONAL', 'personal'), ('ORGANIZATION', 'organization');

insert into settings (setting_name, setting_description) values ('auto_blocking', 'auto blocking min score');
insert into settings (setting_name, setting_description) values ('notifications', 'notifications enabled');
insert into settings (setting_name, setting_description) values ('slack_webhook', 'slack webhook configuration');
insert into settings (setting_name, setting_description) values ('slack_min_score', 'slack min score');
insert into settings (setting_name, setting_description) values ('email_recipients', 'email recipients list');
insert into settings (setting_name, setting_description) values ('email_min_score', 'email min score');
insert into settings (setting_name, setting_description) values ('syslog_endpoints', 'syslog endpoints list');
insert into settings (setting_name, setting_description) values ('syslog_min_score', 'syslog min score');
insert into settings (setting_name, setting_description) values ('size', 'entity size');
insert into settings (setting_name, setting_description) values ('sector', 'industrial sector');

insert into features (feature_name, feature_description) values ('blocking', 'blocking account feature');
insert into features (feature_name, feature_description) values ('exporting', 'exporting account feature');
insert into features (feature_name, feature_description) values ('notifications', 'notifications account feature');
insert into features (feature_name, feature_description) values ('api_tokens', 'api tokens');
insert into features (feature_name, feature_description) values ('reporting', 'reporting feature');

insert into entity_types (entity_type_name, entity_type_description) values ('ACCOUNT', 'Accounts');
insert into entity_types (entity_type_name, entity_type_description) values ('USER', 'Users');
insert into entity_types (entity_type_name, entity_type_description) values ('SENSOR', 'Sensors');

insert into roles (role_name, role_description) values ('USER', 'user role');
insert into roles (role_name, role_description) values ('ADMIN', 'admin role');
insert into roles (role_name, role_description) values ('OWNER', 'owner role');

insert into sensor_type_codes (sensor_type_code, sensor_type_description) values ('SYSLOG', 'syslog');
insert into sensor_type_codes (sensor_type_code, sensor_type_description) values ('ELB', 'elb');
insert into sensor_type_codes (sensor_type_code, sensor_type_description) values ('DEMO', 'demo');
insert into sensor_type_codes (sensor_type_code, sensor_type_description) values ('DEFAULT', 'default');
```

### Clean

```
delete from account_users;
delete from user_access_tokens;
delete from users;
delete from account_features;
delete from account_settings;
delete from legacy_account_xref;
delete from accounts;
delete from sensors;
delete from legacy_sensor_group_xref;
delete from sensor_groups;
delete from sensor_group_xref;
```

## Kafka Stuff

### Command Config

```
cat << EOF > kafka.properties
bootstrap.servers=kafka:9071
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="test" password="test123";
sasl.mechanism=PLAIN
security.protocol=SASL_PLAINTEXT
EOF
```

### Create Topics

```
kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic SyslogSensor-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic Sensor-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic IncomingSyslogStream --partitions 10 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic FailedSyslogStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic FailedSyslog-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic EventStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic GlobalWhitelist-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic AccountWhitelist-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic BlacklistStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic ThreatDatabaseStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic ThreatDatabase-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic ThreatDocStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic ThreatCacheStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic ReportStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic Report-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic Report-loop --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic ForceStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic ScoreStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic Score-loop --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic TrafficFilterStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic TrafficFilter-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic TrafficStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic TrafficDatabaseStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic TrafficDocStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic TrafficCacheStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic PortService-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic InternalNetwork-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic Resolution-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic HighScoreNotifyStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic AutoBlockNotifyStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic Notification-table --partitions 1 --replication-factor 1 --config cleanup.policy=compact

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic BlockStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic MuteStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic UserInviteStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic UserConfirmationStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete

kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create \
  --topic UserPasswordResetStream --partitions 1 --replication-factor 1 --config cleanup.policy=delete
```
