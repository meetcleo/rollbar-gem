module Rollbar
  module WorkerDataExtractor
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    module ClassMethods
      def extract_person_data_from_worker(worker)
        return {} unless worker

        person_data = begin
          worker.rollbar_person_data
        rescue StandardError
          {}
        end

        person_data
      end
    end
  end
end
