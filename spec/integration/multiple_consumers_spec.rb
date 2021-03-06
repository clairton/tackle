require "spec_helper"

describe "Multiple Consumers" do
  before(:all) do
    @tackle_options = {
      :url => "amqp://localhost",
      :exchange => "multiple-consumer-exchange",
      :routing_key => "test-key",
      :retry_delay => 1,
      :retry_limit => 3
    }

    @healthy_service_messages = []
    @healthy_consumer_options = @tackle_options.merge(:service => "multi-healthy-service")

    @healthy_worker = Thread.new do
      Tackle.consume(@healthy_consumer_options) do |message|
        @healthy_service_messages << message
      end
    end

    @broken_service_messages = []
    @broken_consumer_options  = @tackle_options.merge(:service => "multi-broken-service")

    @broken_worker = Thread.new do
      Tackle.consume(@broken_consumer_options) do |message|
        @broken_service_messages << message
        raise "Test exception"
      end
    end

    sleep 2

    Tackle.publish("Hi!", @tackle_options)

    sleep 7
  end

  after(:all) do
    @healthy_worker.kill
    @broken_worker.kill
  end

  describe "healthy service" do
    it "receives the message only once" do
      expect(@healthy_service_messages).to eq(["Hi!"])
    end

    it "clears the queue from messages" do
      expect(BunnyHelper.message_count("multi-healthy-service.test-key")).to eq(0)
    end
  end

  describe "broken service" do
    it "receives the message multiple times" do
      expect(@broken_service_messages).to eq(["Hi!", "Hi!", "Hi!", "Hi!"])
    end

    it "clears the queue from messages" do
      expect(BunnyHelper.message_count("multi-broken-service.test-key")).to eq(0)
    end

    it "puts the message to the dead queue" do
      expect(BunnyHelper.message_count("multi-broken-service.test-key.dead")).to be > 0
    end
  end
end
