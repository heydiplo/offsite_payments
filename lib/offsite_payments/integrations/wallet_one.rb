module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    # Documentation: http://www.walletone.com/ru/merchant/documentation/
    module WalletOne

      mattr_accessor :service_url
      self.service_url = 'https://wl.walletone.com/checkout/checkout/Index'

      mattr_accessor :signature_parameter_name
      self.signature_parameter_name = 'WMI_SIGNATURE'

      def self.helper(order, account, options = {})
        Helper.new(order, account, options)
      end

      def self.notification(query_string, options = {})
        Notification.new(query_string, options)
      end

      module Common

        def generate_signature
          Digest::MD5.base64digest(generate_signature_string)
        end

        def generate_signature_string
          fields = signature_params.clone
          fields.delete(OffsitePayments::Integrations::WalletOne.signature_parameter_name)
          values = fields.sort_by { |k, v| k + v }.map(&:last)
          signature_string = [values, signature_key].join
          signature_string.encode("cp1251")
        end

        def signature_params
          params
        end

        def signature_key
          @secret_key
        end

      end

      class Helper < OffsitePayments::Helper

        include Common

        def initialize(order, account, options = {})
          @secret_key = options.delete(:secret)

          super
        end

        def form_fields
          @secret_key ?
            @fields.merge(OffsitePayments::Integrations::WalletOne.signature_parameter_name => generate_signature) :
            @fields
        end

        def signature_params
          @fields
        end

        mapping :account, 'WMI_MERCHANT_ID'
        mapping :amount, 'WMI_PAYMENT_AMOUNT'
        mapping :currency, 'WMI_CURRENCY_ID'
        mapping :order, 'WMI_PAYMENT_NO'
        mapping :description, 'WMI_DESCRIPTION'
        mapping :return_url, 'WMI_SUCCESS_URL'
        mapping :cancel_return_url, 'WMI_FAIL_URL'

        mapping :customer, :first_name => 'WMI_CUSTOMER_FIRSTNAME',
                           :last_name  => 'WMI_CUSTOMER_LASTNAME',
                           :email      => 'WMI_CUSTOMER_EMAIL'

        def customer(params={})
          add_field(mappings[:customer][:email], params[:email])
          add_field(mappings[:customer][:first_name], params[:first_name])
          add_field(mappings[:customer][:last_name], params[:last_name])
        end

      end

      class Notification < OffsitePayments::Notification

        include Common

        def self.recognizes?(params)
          params.has_key?('WMI_PAYMENT_AMOUNT') && params.has_key?('WMI_MERCHANT_ID')
        end

        def complete?
          status == 'Accepted'
        end

        def account
          params['WMI_MERCHANT_ID']
        end

        def amount
          gross.to_f
        end

        def item_id
          params['WMI_PAYMENT_NO']
        end

        def transaction_id
          params['WMI_ORDER_ID']
        end

        def received_at
          params['WMI_UPDATE_DATE']
        end

        def security_key 
          params[OffsitePayments::Integrations::WalletOne.signature_parameter_name]
        end

        def currency
          params['WMI_CURRENCY_ID']
        end

        def status
          params['WMI_ORDER_STATE']
        end

        def payer_wallet_id
          params['WMI_TO_USER_ID']
        end

        def gross
          params['WMI_PAYMENT_AMOUNT']
        end

        def acknowledge
          security_key == generate_signature
        end

        def success_response(*args)
          "WMI_RESULT=OK"
        end

        # @param message
        def retry_response(message = '', *args)
          "WMI_RESULT=RETRY&WMI_DESCRIPTION=#{message}"
        end

        def signature_key
          @options[:secret]
        end

      end

    end
  end
end
