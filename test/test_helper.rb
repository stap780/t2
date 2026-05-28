ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def with_singleton_stub(object, method_name, replacement)
      singleton = object.singleton_class
      backup = :"__stub_backup_#{method_name}_#{object.object_id}"
      singleton.alias_method(backup, method_name)
      if replacement.is_a?(Proc)
        singleton.define_method(method_name, &replacement)
      else
        singleton.define_method(method_name) { |*_args, **_kwargs, &_block| replacement }
      end
      yield
    ensure
      singleton.define_method(method_name, singleton.instance_method(backup))
      singleton.remove_method(backup)
    end
  end
end
