require 'spec_helper'

describe Fastdfs::Client::Tracker do 
  let(:server){ {host: "192.168.1.168", port: "22122"} }
  let(:tracker){ FC::Tracker.new(trackers: server) }

  it "initialize the server" do 
    expect(FC::Socket).to receive(:new).with(server[:host], server[:port], TestConfig::SOCKET_DEFAULT_OPTION) 
    FC::Tracker.new(trackers: server) 
  end

  it "should have access to the storage class" do 
    expect(tracker.get_storage.class).to eq(FC::Storage)
  end

  it "verify the server address and port" do 
    storage = tracker.get_storage
    expect(storage.proxy.host).to eq(TestConfig::STORAGE_IP)

    expect(storage.proxy.port.to_s).to eq(TestConfig::STORAGE_PORT)
    expect(storage.store_path).to eq(TestConfig::STORE_PATH)
  end

  it "get to the server failed" do 
    if tracker.get_storage.socket.is_a?(MockTCPSocket)
      result = FC::ProtoCommon.header_bytes(FC::CMD::RESP_CODE, 0, 22)
      MockTCPSocket.any_instance.stub("recv").and_return(result.pack("C*"))
      expect(tracker.get_storage).to be_a_kind_of(Hash)
      expect(tracker.get_storage[:status]).to be_falsey
    end
  end

  it "multi thread upload" do 
    items = 6.times.map do
      Thread.new do 
        storage = tracker.get_storage
        res = storage.upload(File.open(File.expand_path("../page.png", __FILE__)))
        expect(res[:status]).to be_truthy
        results = res[:result]
        res = storage.delete(results[:path], results[:group_name])
        expect(res[:status]).to be_truthy
      end
    end

    items.map(&:join)
  end

  it "should be storage methods" do 
    expect(tracker.respond_to?(:upload)).to be_truthy
    expect(tracker.respond_to?(:delete)).to be_truthy
    expect(tracker.respond_to?(:get_metadata)).to be_truthy
    expect(tracker.respond_to?(:set_metadata)).to be_truthy
    expect(tracker.respond_to?(:download)).to be_truthy
  end

  it "storage socket keepalive request" do 
    storage = tracker.pipeline do |storage|
      res = storage.upload(File.open(File.expand_path("../page.png", __FILE__)))[:result]
      expect(storage.socket.connected).to be_truthy

      tmp = storage.set_metadata(res[:path], res[:group_name], TestConfig::METADATA)
      expect(tmp[:status]).to be_truthy
      expect(storage.socket.connected).to be_truthy

      tmp = storage.get_metadata(res[:path], res[:group_name])
      expect(tmp[:status]).to be_truthy
      expect(storage.socket.connected).to be_truthy

      tmp = storage.download(res[:path], res[:group_name])
      expect(tmp[:status]).to be_truthy
      expect(storage.socket.connected).to be_truthy
    end
    expect(storage.socket.connected).to be_falsey
  end

  it "multiple trackers server proxy" do 
    trackers = [server]
    two_server = {host: "192.168.1.169", port: "22122"}
    trackers << two_server
    ts = FC::Tracker.new(trackers: trackers)

    1.upto(6).each do |i|
      proxy = ts.send(:proxy)
      res = i % 2 == 0 ?  two_server : server
      expect({host: proxy.host, port: proxy.port}).to eq(res)
    end
  
  end
end