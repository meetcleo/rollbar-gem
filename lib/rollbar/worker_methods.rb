require 'rollbar/worker_data_extractor'
require 'rollbar/util'

module Rollbar
  module WorkerMethods
    include WorkerDataExtractor

    def rollbar_person_data
      user = nil
      unless Rollbar::Util.method_in_stack_twice(:rollbar_person_data, __FILE__)
        user = send(Rollbar.configuration.person_method)
      end

      # include id, username, email if non-empty
      if user
        {
          :id => (begin
            user.send(Rollbar.configuration.person_id_method)
          rescue StandardError
            nil
          end),
          :username => (begin
            user.send(Rollbar.configuration.person_username_method)
          rescue StandardError
            nil
          end),
          :email => (begin
            user.send(Rollbar.configuration.person_email_method)
          rescue StandardError
            nil
          end)
        }
      else
        {}
      end
    rescue NameError
      {}
    end
  end
end
