module Resque
  module Failure
    # A Failure backend that stores exceptions in Mongo. Very simple but
    # works out of the box, along with support in the Resque web app.
    class Redis < Base
      def save
        data = {
          :failed_at => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
          :payload   => payload,
          :exception => exception.class.to_s,
          :error     => exception.to_s,
          :backtrace => filter_backtrace(Array(exception.backtrace)),
          :worker    => worker.to_s,
          :queue     => queue
        }
        #Resque.mongo_failures << data
        Resque.mongo_failures.insert_one(data)
      end

      def self.count
        Resque.mongo_failures.count
      end

      def self.all(start = 0, count = 1)
        #all_failures = Resque.mongo_failures.find().sort([:natural, :desc]).skip(start).limit(count).to_a
        all_failures = Resque.mongo_failures.find().sort(natural: -1).skip(start).limit(count).to_a
       # all_failures.size == 1 ? all_failures.first : all_failures        
      end

      def self.clear
        #Resque.mongo_failures.remove
        Resque.mongo_failures.delete_many
      end

      def self.requeue(index)
        item = all(index)
        item['retried_at'] = Time.now.strftime("%Y/%m/%d %H:%M:%S")
        Resque.redis.lset(:failed, index, Resque.encode(item))
        Job.create(item['queue'], item['payload']['class'], *item['payload']['args'])
      end

      def self.remove(index)
        id = rand(0xffffff)
        Resque.redis.lset(:failed, index, id)
        Resque.redis.lrem(:failed, 1, id)
      end

      def filter_backtrace(backtrace)
        index = backtrace.index { |item| item.include?('/lib/resque/job.rb') }
        backtrace.first(index.to_i)
      end
    end
  end
end
