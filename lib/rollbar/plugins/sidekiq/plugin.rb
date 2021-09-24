require 'rollbar/scrubbers/params'
require 'rollbar/worker_data_extractor'

module Rollbar
  class Sidekiq
    PARAM_BLACKLIST = %w[backtrace error_backtrace error_message error_class].freeze
    include WorkerDataExtractor

    class ResetScope
      def call(worker, msg, _queue, &block)
        Rollbar.reset_notifier! # clears scope

        return yield unless Rollbar.configuration.sidekiq_use_scoped_block

        Rollbar.scoped(Rollbar::Sidekiq.job_scope(msg, worker: worker), &block)
      end
    end

    def self.handle_exception(msg, e, worker: nil)
      return if skip_report?(msg, e)

      Rollbar.scope(job_scope(msg, worker: worker)).error(e, :use_exception_level_filters => true)
    end

    def self.skip_report?(msg, _e)
      job_hash = job_hash_from_msg(msg)

      return false if job_hash.nil?

      # when rollbar middleware catches, sidekiq's retry_job processor hasn't set
      # the retry_count for the current job yet, so adding 1 gives the actual retry count
      actual_retry_count = job_hash.fetch('retry_count', -1) + 1
      job_hash['retry'] && actual_retry_count < ::Rollbar.configuration.sidekiq_threshold
    end

    def self.job_scope(msg, worker: nil)
      scope = {
        :framework => "Sidekiq: #{::Sidekiq::VERSION}",
        :person => person_data_proc(worker)
      }
      job_hash = job_hash_from_msg(msg)

      unless job_hash.nil?
        params = job_hash.reject { |k| PARAM_BLACKLIST.include?(k) }
        scope[:request] = { :params => scrub_params(params) }
        scope[:context] = params['class']
        scope[:queue] = params['queue']
      end

      scope
    end

    def self.person_data_proc(worker)
      proc { extract_person_data_from_worker(worker) }
    end

    def self.scrub_params(params)
      options = {
        :params => params,
        :config => Rollbar.configuration.scrub_fields
      }

      Rollbar::Scrubbers::Params.call(options)
    end

    # see https://github.com/mperham/sidekiq/wiki/Middleware#server-middleware
    def call(worker, msg, _queue, &block)
      Rollbar.reset_notifier! # clears scope

      return yield unless Rollbar.configuration.sidekiq_use_scoped_block

      Rollbar.scoped(Rollbar::Sidekiq.job_scope(msg, worker: worker), &block)
    rescue Exception => e # rubocop:disable Lint/RescueException
      Rollbar::Sidekiq.handle_exception(msg, e, worker: worker)
      raise
    end

    def self.job_hash_from_msg(msg)
      msg && (msg[:job] || msg)
    end
    private_class_method :job_hash_from_msg
  end
end
