module Citygram::Workers
  class SubscriptionConfirmation
    include Sidekiq::Worker
    sidekiq_options retry: 5

    def perform(subscription_id)
      subscription = Subscription.first!(id: subscription_id)
      publisher = subscription.publisher

      # TODO: get rid of this case statement
      case subscription.channel
      when 'sms'
        body = "Welcome! You are now subscribed to #{publisher.title} in #{publisher.city}. Woohoo! If you'd like to give feedback, text back with your email. To unsubscribe from all messages, reply STOP."

        Citygram::Services::Channels::SMS.sms(
          from: Citygram::Services::Channels::SMS::FROM_NUMBER,
          to: subscription.phone_number,
          body: body
        )
      when 'email'
        # TODO
      end
    rescue Twilio::REST::RequestError => e
      Citygram::App.logger.error(e)

      if e.code.to_i == Citygram::Services::Channels::SMS::UNSUBSCRIBED_ERROR_CODE
        # unsubscribe and skip retries if the user has
        # replied with a filter word
        subscription.unsubscribe!
      else
        raise Citygram::Services::Channels::NotificationFailure, e
      end
    end
  end
end
