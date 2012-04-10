require 'test_helper'

context "Resque" do
  setup do
    Resque.drop
    Resque.enable_delay(:delayed)
    Resque.push(:people, { 'name' => 'chris' })
    Resque.push(:people, { 'name' => 'bob' })
    Resque.push(:people, { 'name' => 'mark' })
  end

  test "uses database called resque by default" do
    assert 'resque', Resque.mongo.name
  end

  test "can set a database with a Mongo::DB" do
    Resque.mongo = Mongo::Connection.new.db('resque-test-with-specific-database')
    assert_equal 'resque-test-with-specific-database', Resque.mongo.name
  end
  
  test "can not set a database with a uri string" do
    assert_raise(ArgumentError) { Resque.mongo = 'localhost:27017/namespace' }
  end

  test "can put jobs on a queue" do
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
  end

  test "can grab jobs off a queue" do
    Resque::Job.create(:jobs, 'some-job', 20, '/tmp')

    job = Resque.reserve(:jobs)

    assert_kind_of Resque::Job, job
    assert_equal SomeJob, job.payload_class
    assert_equal 20, job.args[0]
    assert_equal '/tmp', job.args[1]
  end

  test "can re-queue jobs" do
    Resque::Job.create(:jobs, 'some-job', 20, '/tmp')

    job = Resque.reserve(:jobs)
    job.recreate

    assert_equal job, Resque.reserve(:jobs)
  end

  test "can put jobs on a queue by way of an ivar" do
    assert_equal 0, Resque.size(:ivar)
    assert Resque.enqueue(SomeIvarJob, 20, '/tmp')
    assert Resque.enqueue(SomeIvarJob, 20, '/tmp')

    job = Resque.reserve(:ivar)

    assert_kind_of Resque::Job, job
    assert_equal SomeIvarJob, job.payload_class
    assert_equal 20, job.args[0]
    assert_equal '/tmp', job.args[1]

    assert Resque.reserve(:ivar)
    assert_equal nil, Resque.reserve(:ivar)
  end

  test "can remove jobs from a queue by way of an ivar" do
    assert_equal 0, Resque.size(:ivar)
    assert Resque.enqueue(SomeIvarJob, 20, '/tmp')
    assert Resque.enqueue(SomeIvarJob, 30, '/tmp')
    assert Resque.enqueue(SomeIvarJob, 20, '/tmp')
    assert Resque::Job.create(:ivar, 'blah-job', 20, '/tmp')
    assert Resque.enqueue(SomeIvarJob, 20, '/tmp')
    assert_equal 5, Resque.size(:ivar)

    assert Resque.dequeue(SomeIvarJob, 30, '/tmp')
    assert_equal 4, Resque.size(:ivar)
    assert Resque.dequeue(SomeIvarJob)
    assert_equal 1, Resque.size(:ivar)
  end

  test "jobs have a nice #inspect" do
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    job = Resque.reserve(:jobs)
    assert_equal '(Job{jobs} | SomeJob | [20, "/tmp"])', job.inspect
  end

  test "jobs can be destroyed" do
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'BadJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'BadJob', 30, '/tmp')
    assert Resque::Job.create(:jobs, 'BadJob', 20, '/tmp')

    assert_equal 5, Resque.size(:jobs)
    assert_equal 2, Resque::Job.destroy(:jobs, 'SomeJob')
    assert_equal 3, Resque.size(:jobs)
    assert_equal 1, Resque::Job.destroy(:jobs, 'BadJob', 30, '/tmp')
    assert_equal 2, Resque.size(:jobs)
  end

  test "jobs can test for equality" do
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'some-job', 20, '/tmp')
    assert_equal Resque.reserve(:jobs), Resque.reserve(:jobs)

    assert Resque::Job.create(:jobs, 'SomeMethodJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert_not_equal Resque.reserve(:jobs), Resque.reserve(:jobs)

    assert Resque::Job.create(:jobs, 'SomeJob', 20, '/tmp')
    assert Resque::Job.create(:jobs, 'SomeJob', 30, '/tmp')
    assert_not_equal Resque.reserve(:jobs), Resque.reserve(:jobs)
  end

  test "can put jobs on a queue by way of a method" do
    assert_equal 0, Resque.size(:method)
    assert Resque.enqueue(SomeMethodJob, 20, '/tmp')
    assert Resque.enqueue(SomeMethodJob, 20, '/tmp')

    job = Resque.reserve(:method)

    assert_kind_of Resque::Job, job
    assert_equal SomeMethodJob, job.payload_class
    assert_equal 20, job.args[0]
    assert_equal '/tmp', job.args[1]

    assert Resque.reserve(:method)
    assert_equal nil, Resque.reserve(:method)
  end

  test "can define a queue for jobs by way of a method" do
    assert_equal 0, Resque.size(:method)
    assert Resque.enqueue_to(:new_queue, SomeMethodJob, 20, '/tmp')

    job = Resque.reserve(:new_queue)
    assert_equal SomeMethodJob, job.payload_class
    assert_equal 20, job.args[0]
    assert_equal '/tmp', job.args[1]
  end

  test "needs to infer a queue with enqueue" do
    assert_raises Resque::NoQueueError do
      Resque.enqueue(SomeJob, 20, '/tmp')
    end
  end

  test "validates job for queue presence" do
    assert_raises Resque::NoQueueError do
      Resque.validate(SomeJob)
    end
  end

  test "can put items on a queue" do
    assert Resque.push(:people, { 'name' => 'jon' })
  end

  def pop_no_id(queue)
    item = Resque.pop(queue)
    item.delete("_id")
    item
  end

  test "can pull items off a queue" do
    assert_equal('chris', pop_no_id(:people)['name'])
    assert_equal('bob', pop_no_id(:people)['name']) 
    assert_equal('mark', pop_no_id(:people)['name'])
    assert_equal nil, Resque.pop(:people)
  end

  test "knows how big a queue is" do
    assert_equal 3, Resque.size(:people)

    assert_equal('chris', pop_no_id(:people)['name'])
    assert_equal 2, Resque.size(:people)

    assert_equal('bob', pop_no_id(:people)['name'])
    assert_equal('mark', pop_no_id(:people)['name'])
    assert_equal 0, Resque.size(:people)
  end

  test "can peek at a queue" do
    peek = Resque.peek(:people)
    peek.delete "_id"
    assert_equal('chris', peek['name'])
    assert_equal 3, Resque.size(:people)
  end

  test "can peek multiple items on a queue" do
    assert_equal('bob', Resque.peek(:people, 1, 1)['name'])
    peek = Resque.peek(:people, 1, 2).map {  |hash| { 'name' => hash['name']}}
    assert_equal([{ 'name' => 'bob' }, { 'name' => 'mark' }], peek)
    peek = Resque.peek(:people, 0, 2).map {  |hash| { 'name' => hash['name']} }
    assert_equal([{ 'name' => 'chris' }, { 'name' => 'bob' }], peek)
    peek = Resque.peek(:people, 0, 3).map {  |hash| { 'name' => hash['name']} }
    assert_equal([{ 'name' => 'chris' }, { 'name' => 'bob' }, { 'name' => 'mark' }], peek)
    peek = Resque.peek(:people, 2, 1)
    assert_equal('mark', peek['name'])
    assert_equal nil, Resque.peek(:people, 3)
    assert_equal [], Resque.peek(:people, 3, 2)
  end

  test "knows what queues it is managing" do
    assert_equal %w( people ), Resque.queues
    Resque.push(:cars, { 'make' => 'bmw' })
    assert_equal %w( cars people ), Resque.queues.sort
  end

  test "does not confuse normal collections on the same database with queues" do
    Resque.mongo["some_other_collection"] << {:foo => 'bar'}
    Resque.push(:cars, { 'make' => 'bmw' })
    assert_equal %w( cars people ), Resque.queues.sort
  end

  test "queues are always a list" do
    Resque.drop
    assert_equal [], Resque.queues
  end

  test "can get the collection for a queue" do
    collection = Resque.collection_for_queue(:people)
    assert_equal Mongo::Collection, collection.class
    assert_equal 3, collection.count
  end

  test "can delete a queue" do
    Resque.push(:cars, { 'make' => 'bmw' })
    assert_equal %w( cars people ), Resque.queues.sort
    Resque.remove_queue(:people)
    assert_equal %w( cars ), Resque.queues
    assert_equal nil, Resque.pop(:people)
  end

  test "keeps track of resque keys" do
    assert Resque.keys.include? 'resque.queues.people'
  end

  test "badly wants a class name, too" do
    assert_raises Resque::NoClassError do
      Resque::Job.create(:jobs, nil)
    end
  end

  test "keeps stats" do
    Resque::Job.create(:jobs, SomeJob, 20, '/tmp')
    Resque::Job.create(:jobs, BadJob)
    Resque::Job.create(:jobs, GoodJob)

    Resque::Job.create(:others, GoodJob)
    Resque::Job.create(:others, GoodJob)

    stats = Resque.info
    assert_equal 8, stats[:pending]

    @worker = Resque::Worker.new(:jobs)
    @worker.register_worker
    2.times { @worker.process }

    job = @worker.reserve
    @worker.working_on job

    stats = Resque.info
    assert_equal 1, stats[:working]
    assert_equal 1, stats[:workers]

    @worker.done_working

    stats = Resque.info
    assert_equal 3, stats[:queues]
    assert_equal 3, stats[:processed]
    assert_equal 1, stats[:failed]
 #   assert_equal [Resque.redis.respond_to?(:server) ? 'localhost:9736' : 'redis://localhost:9736/0'], stats[:servers]
  end

  test "decode bad json" do
    assert_raises Resque::Helpers::DecodeException do
      Resque.decode("{\"error\":\"Module not found \\u002\"}")
    end
  end

  test "delayed jobs work" do
    args = { :delay_until => Time.new-1}
    Resque.enqueue(DelayedJob, args)
    job = Resque::Job.reserve(:delayed)
    assert_equal(1, job.args[0].keys.length)
    assert_equal(args[:delay_until].to_i, job.args[0]["delay_until"].to_i)
    args[:delay_until] = Time.new + 2
    assert_equal(0, Resque.delayed_size(:delayed))
    Resque.enqueue(DelayedJob, args)
    
    assert_equal(1, Resque.delayed_size(:delayed))
    assert_nil Resque.peek(:delayed)
    assert_nil Resque::Job.reserve(:delayed)
    sleep 1
    assert_nil Resque::Job.reserve(:delayed)
    sleep 1
    assert_equal(DelayedJob, Resque::Job.reserve(:delayed).payload_class)
  end

  test "mixing delay and non-delay is bad" do
    dargs = { :delay_until => Time.new + 3600}
    
    #non-delay into delay
    assert_raise(Resque::QueueError) do
      Resque.enqueue(NonDelayedJob, dargs)
    end
    
    #delay into non-delay
    assert_raise(Resque::QueueError) do
      Resque.enqueue(MistargetedDelayedJob, dargs)
    end
  end

  test "inlining jobs" do
    begin
      Resque.inline = true
      Resque.enqueue(SomeIvarJob, 20, '/tmp')
      assert_equal 0, Resque.size(:ivar)
    ensure
      Resque.inline = false
    end
  end
end
