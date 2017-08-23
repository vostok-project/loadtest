import org.apache.avro.Schema;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.common.errors.WakeupException;
import org.rapidoid.log.Log;
import org.rapidoid.net.Server;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Arrays;
import java.util.Properties;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

public class KLoadEntryPoint {

    public static void main(String[] args) throws Exception {
        Properties props = new Properties();
        props.put("bootstrap.servers", "icat-test01:9092");
        props.put("schema.registry.url", "http://icat-test01:8881");
        String schemaString = "{\"type\": \"record\", " +
                "\"name\": \"kevent\"," +
                "\"fields\": [" +
                "{\"name\": \"timestamp\", \"type\": \"long\"}," +
                "{\"name\": \"payload\", \"type\": \"bytes\"}" +
                "]}";
        Schema.Parser parser = new Schema.Parser();
        Schema schema = parser.parse(schemaString);
        String topic = "ktopic-with-ts";
        if (args != null && args.length > 0) {
            String mode = args[0];
            if (mode.equals("gate"))
                RunHttpGate(props, schema, topic);
            else if (mode.equals("consumer"))
                RunConsumer(props, schema, topic);
            else
                Log.error("KLoad mode is not recognized: " + mode);
        } else {
            Log.error("KLoad mode is not specified");
        }
    }

    private static void RunConsumer(Properties props, Schema schema, String topic) {
        Logger.getLogger("kafka").setLevel(Level.INFO);

        Log.info("Starting consumer");

        props.put("group.id", "kgroup" + System.currentTimeMillis());
        props.put("auto.offset.reset", "latest");
        props.put("enable.auto.commit", "true");
        props.put("auto.commit.interval.ms", 1000);
        props.put("session.timeout.ms", "60000");
        props.put("key.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer");
        props.put("value.deserializer", "io.confluent.kafka.serializers.KafkaAvroDeserializer");
        KafkaConsumer<String, GenericRecord> consumer = new KafkaConsumer<>(props);
        consumer.subscribe(Arrays.asList(topic));
        try {
            while (true) {
                ConsumerRecords<String, GenericRecord> records = consumer.poll(Long.MAX_VALUE);
                long currentTimestamp = System.currentTimeMillis();
                for (ConsumerRecord<String, GenericRecord> record : records) {
                    long travelTime = currentTimestamp - (long) record.value().get("timestamp");
                    Log.info("[" + record.partition() + ":" + record.offset() + "]: " + record.value() + " (tt = " + formatDuration(travelTime) + ")");
                }
            }
        } catch (WakeupException e) {
            // ignore for shutdown via consumer.wakeup()
        } finally {
            consumer.close();
        }
    }

    private static String formatDuration(long durationMillis) {
        long totalMinutes = TimeUnit.MILLISECONDS.toMinutes(durationMillis);
        long totalSeconds = TimeUnit.MILLISECONDS.toSeconds(durationMillis);
        long seconds = totalSeconds - TimeUnit.MINUTES.toSeconds(totalMinutes);
        long millis = durationMillis - TimeUnit.SECONDS.toMillis(totalSeconds);
        return String.format("%d:%02d:%03d", totalMinutes, seconds, millis);
    }

    private static void RunHttpGate(Properties props, Schema schema, String topic) throws IOException {
        Log.info("Starting http gate");

        props.put("acks", "1");
        props.put("retries", 0);
        props.put("linger.ms", 20);
        props.put("batch.size", 64 * 1000);
        props.put("buffer.memory", 256 * 1000 * 1000);
        props.put("max.request.size", 20 * 1000 * 1000);
        props.put("compression.type", "none");
        props.put("metadata.fetch.timeout.ms", 25);
        props.put("max.block.ms", 25);
        props.put("max.in.flight.requests.per.connection", 500);
        props.put("key.serializer", "io.confluent.kafka.serializers.KafkaAvroSerializer");
        props.put("value.serializer", "io.confluent.kafka.serializers.KafkaAvroSerializer");

        Producer<String, GenericRecord> producer = new KafkaProducer<>(props);
        Server server = new KHttpServer(schema, producer, topic).listen(8888);
        new BufferedReader(new InputStreamReader(System.in)).readLine();
        server.shutdown();
        producer.close();
    }
}