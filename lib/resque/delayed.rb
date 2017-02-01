module Resque
  module DelayedJob
    def before_enqueue_with_delay(*args)
      unless Resque.delayed_queue?(self)
        raise DelayedQueueError.new 'trying to insert a delayed job into a non-delayed queue' 
      end
      unless args[0].is_a?(Hash) && args[0].has_key?(:delay_until)
        raise DelayedQueueError.new 'trying to insert delayed job without delay_until'
      end
    end

    def before_create_with_delay(item, *args)
      item[:delay_until] = args[0][:delay_until]
    end

    def before_pop_with_delay(query)
      query['delay_until'] = {'$lt' => Time.now } if delayed_queue?(queue)
    end
  end
  
  module Delayed
    def self.extended(base)
      base.class_eval { @delayed_queues = [] }
    end

    def initialize_delayed
      #delayed_queues = mongo_stats.find_one(:stat => 'Delayed Queues')
      delayed_queues = mongo_stats.find(:stat => 'Delayed Queues').limit(1).first
      @delayed_queues = delayed_queues['value'] if delayed_queues
    end

    def delayed_job?(klass)
      klass.instance_variable_get(:@delayed) ||
        (klass.respond_to?(:delayed) and klass.delayed)
    end

    def delayed_queue?(queue)
      @delayed_queues.include? namespace_queue(queue)
    end

    def enable_delay(queue)
      queue = namespace_queue(queue)
      unless delayed_queue? queue
        @delayed_queues << queue
        #mongo_stats.update({:stat => 'Delayed Queues'}, {'$addToSet' => {'value' => queue}}, {:upsert => true})
        mongo_stats.update_one({:stat => 'Delayed Queues'}, {'$addToSet' => {'value' => queue}}, {:upsert => true})
      end
    end

    def delayed_size(queue)
      queue = namespace_queue(queue)
      if delayed_queue? queue
        mongo[queue].find({'delay_until' => { '$gt' => Time.now }}).count
      else
        mongo[queue].count
      end
    end

    def ready_size(queue)
      queue = namespace_queue(queue)
      if delayed_queue? queue
        mongo[queue].find({'delay_until' => { '$lt' => Time.now }}).count
      else
        mongo[queue].count
      end
    end
  end
  
  class DelayedQueueError < RuntimeError; end
end
