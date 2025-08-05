#!/usr/bin/env ruby

require 'async'
require 'async/http'
require 'async/semaphore'
require 'json'
require 'time'
require 'fileutils'
require 'tmpdir'

class OllamaLoadTester
  # Configuration
  BASE_URL = "https://ollama.chainfetch.app"
  ENDPOINT_PATH = "/api/embeddings"
  BEARER_TOKEN = "u82736GTDV28DME08HD87H3D3JHGD33ed"
  REQUESTS_PER_BATCH = 5
  BATCHES = 60
  BATCH_INTERVAL = 0.5
  TEST_TEXT = "Artificial intelligence and machine learning are transforming how we interact with technology. From natural language processing to computer vision, these advanced systems are becoming increasingly sophisticated and capable of handling complex tasks with remarkable accuracy and efficiency."

  def initialize
    @temp_dir = Dir.mktmpdir("ollama_load_test_")
    @all_times = []
    @all_successful = 0
    @batch_results = []
    @overall_start = nil
    
    puts "🚀 Starting sustained load Ollama performance test..."
    puts "📊 Testing: #{BATCHES} batches × #{REQUESTS_PER_BATCH} concurrent requests"
    puts "⏱️  #{BATCH_INTERVAL}-second intervals between batches"
    puts "🎯 Target: #{BASE_URL + ENDPOINT_PATH}"
    puts "📁 Results directory: #{@temp_dir}"
    puts
  end

  def run
    @overall_start = Time.now
    
    Async do |task|
      # Launch all batches with intervals
      batch_tasks = []
      
      (1..BATCHES).each do |batch_num|
        batch_tasks << task.async do
          # Wait for the appropriate start time for this batch
          delay = (batch_num - 1) * BATCH_INTERVAL
          task.sleep(delay) if delay > 0
          
          puts
          puts "🔥 ===== LAUNCHING BATCH #{batch_num}/#{BATCHES} ===== 🔥"
          puts "⏰ Time: #{Time.now.strftime('%H:%M:%S')}"
          
          run_batch(batch_num, task)
        end
      end
      
      puts
      puts "🏁 ===== ALL BATCHES LAUNCHED ====="
      puts "⏳ Waiting for all batches to complete..."
      
      # Wait for all batches to complete
      batch_tasks.each(&:wait)
      
      generate_final_report
    end
  ensure
    FileUtils.rm_rf(@temp_dir)
  end

  private

  def run_batch(batch_num, parent_task)
    puts "🏁 Launching Batch #{batch_num}: #{REQUESTS_PER_BATCH} concurrent requests..."
    
    batch_start = Time.now
    batch_times = []
    batch_successful = 0
    
    # Create HTTP client for this batch
    Async do |task|
      endpoint = Async::HTTP::Endpoint.parse(BASE_URL)
      
      Async::HTTP::Client.open(endpoint) do |client|
        # Launch concurrent requests for this batch
        request_tasks = []
        
        (1..REQUESTS_PER_BATCH).each do |request_id|
          request_tasks << task.async do
            make_request(client, batch_num, request_id)
          end
        end
        
        # Wait for all requests in this batch to complete
        results = request_tasks.map(&:wait)
        
        # Process results
        results.each do |result|
          if result && result[:success] && result[:time]
            batch_times << result[:time]
            @all_times << result[:time]
            batch_successful += 1
            @all_successful += 1
          end
        end
      end
    end
    
    batch_end = Time.now
    batch_duration = batch_end - batch_start
    
    # Calculate batch statistics
    if batch_times.any?
      sorted_times = batch_times.sort
      min_time = sorted_times.first
      max_time = sorted_times.last
      avg_time = batch_times.sum / batch_times.length
      median_time = sorted_times[sorted_times.length / 2]
      throughput = batch_successful / batch_duration
      
      result_summary = "Batch #{batch_num}: #{batch_successful}/#{REQUESTS_PER_BATCH} successful, " \
                      "avg: #{'%.3f' % avg_time}s, median: #{'%.3f' % median_time}s, " \
                      "throughput: #{'%.2f' % throughput} req/s"
      
      @batch_results << result_summary
      
      puts "📊 Batch #{batch_num} Results:"
      puts "   • Successful: #{batch_successful}/#{REQUESTS_PER_BATCH}"
      puts "   • Duration: #{'%.3f' % batch_duration}s"
      puts "   • Average response: #{'%.3f' % avg_time}s"
      puts "   • Median response: #{'%.3f' % median_time}s"
      puts "   • Min response: #{'%.3f' % min_time}s"
      puts "   • Max response: #{'%.3f' % max_time}s"
      puts "   • Throughput: #{'%.2f' % throughput} req/s"
    else
      puts "❌ Batch #{batch_num}: No successful requests"
    end
  end

  def make_request(client, batch_num, request_id)
    request_start = Time.now
    
    headers = {
      'Authorization' => "Bearer #{BEARER_TOKEN}",
      'Content-Type' => 'application/json'
    }
    
    body = {
      model: "dengcao/Qwen3-Embedding-0.6B:Q8_0",
      prompt: TEST_TEXT
    }.to_json
    
    begin
      response = client.post(ENDPOINT_PATH, headers, body)
      request_end = Time.now
      total_time = request_end - request_start
      
      if response.status == 200
        puts "✅ Batch #{batch_num} Request #{request_id} completed (#{('%.3f' % total_time)}s)"
        
        # Save response for analysis
        response_file = File.join(@temp_dir, "response_b#{batch_num}_r#{request_id}.json")
        File.write(response_file, response.read)
        
        return {
          success: true,
          time: total_time,
          status: response.status
        }
      else
        puts "❌ Batch #{batch_num} Request #{request_id} failed: HTTP #{response.status}"
        return { success: false, status: response.status }
      end
      
    rescue => e
      request_end = Time.now
      total_time = request_end - request_start
      puts "❌ Batch #{batch_num} Request #{request_id} error: #{e.message} (#{('%.3f' % total_time)}s)"
      return { success: false, error: e.message, time: total_time }
    end
  end

  def generate_final_report
    overall_end = Time.now
    overall_duration = overall_end - @overall_start
    
    puts
    puts "📈 Analyzing overall results..."
    
    if @all_times.any?
      sorted_times = @all_times.sort
      min_time = sorted_times.first
      max_time = sorted_times.last
      avg_time = @all_times.sum / @all_times.length
      median_time = sorted_times[sorted_times.length / 2]
      p95_index = [(sorted_times.length * 0.95).to_i, sorted_times.length - 1].min
      p95_time = sorted_times[p95_index]
      overall_throughput = @all_successful / overall_duration
      
      puts
      puts "🎯 ===== SUSTAINED LOAD TEST RESULTS ===== 🎯"
      puts
      puts "🔄 Test Configuration:"
      puts "   • Batches: #{BATCHES}"
      puts "   • Requests per batch: #{REQUESTS_PER_BATCH}"
      puts "   • Total requests: #{BATCHES * REQUESTS_PER_BATCH}"
      puts "   • Interval between batches: #{BATCH_INTERVAL}s"
      puts
      puts "📊 Overall Summary:"
      puts "   • Total successful requests: #{@all_successful}/#{BATCHES * REQUESTS_PER_BATCH}"
      puts "   • Failed requests: #{(BATCHES * REQUESTS_PER_BATCH) - @all_successful}"
      puts "   • Overall test duration: #{'%.3f' % overall_duration}s"
      puts
      puts "⏱️  Response Time Statistics:"
      puts "   • Average response time: #{'%.3f' % avg_time}s"
      puts "   • Median response time: #{'%.3f' % median_time}s"
      puts "   • Fastest response: #{'%.3f' % min_time}s"
      puts "   • Slowest response: #{'%.3f' % max_time}s"
      puts "   • 95th percentile: #{'%.3f' % p95_time}s"
      puts
      puts "🚀 Performance Metrics:"
      puts "   • Overall throughput: #{'%.2f' % overall_throughput} requests/second"
      puts "   • Load balancing: 5 Ollama pods + GPU acceleration"
      puts
      puts "📈 Batch-by-Batch Results:"
      @batch_results.each do |result|
        puts "   • #{result}"
      end
      puts
      puts "💾 Character count per request: #{TEST_TEXT.length}"
      puts "🧠 Model: dengcao/Qwen3-Embedding-0.6B:Q8_0"
      
      # Analyze a sample response
      sample_response_file = File.join(@temp_dir, "response_b1_r1.json")
      if File.exist?(sample_response_file)
        begin
          response_data = JSON.parse(File.read(sample_response_file))
          response_size = File.size(sample_response_file)
          embedding_dims = response_data.dig('embedding')&.length || 'Unknown'
          
          puts
          puts "📤 Response Details:"
          puts "   • Response size: #{response_size} bytes"
          puts "   • Embedding dimensions: #{embedding_dims}"
        rescue JSON::ParserError
          puts "   • Could not parse sample response"
        end
      end
      
      puts
      puts "✨ Sustained load test completed successfully!"
    else
      puts "❌ No successful requests completed"
    end
  end
end

# Run the test
if __FILE__ == $0
  tester = OllamaLoadTester.new
  tester.run
end 