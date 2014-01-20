module NetsuiteIntegration
  module Services
    # Make sure "Sell Downloadble Files" is enabled in your NetSuite account
    # otherwise search won't work
    #
    # In order to retrieve a Matrix Item you also need to enable "Matrix Items"
    # in your Company settings
    #
    # Specify Item type because +search+ maps to NetSuite ItemSearch object
    # which will bring all kinds of items and not only inventory items
    #
    # Records need to be ordered by lastModifiedDate programatically since
    # NetSuite api doesn't allow us to do that on the request. That's the
    # reason the search lets the page size default of 1000 records. We'd better
    # catch all items at once and sort by date properly or we might end up
    # losing data
    class InventoryItem < Base
      def latest
        ignore_future.sort_by { |c| c.last_modified_date.utc }
      end

      def find_by_name(name)
        NetSuite::Records::InventoryItem.search({
          criteria: {
            basic: [{
              field: 'displayName',
              value: name,
              operator: 'contains'
            }]
          }
        }).results.first
      end

      def find_by_item_id(internal_id)
        NetSuite::Records::InventoryItem.get(internal_id)
      end

      private
        # We might need to set bodyFieldsOnly false to grab more data from items
        def search
          NetSuite::Records::InventoryItem.search({
            criteria: {
              basic: [
                {
                  field: 'lastModifiedDate',
                  operator: 'after',
                  value: last_updated_after
                },
                {
                  field: 'type',
                  operator: 'anyOf',
                  type: 'SearchEnumMultiSelectField',
                  value: ['_inventoryItem']
                },
                {
                  field: 'cost',
                  operator: 'greaterThan',
                  value: 0
                },
                {
                  field: 'isInactive',
                  value: false
                }
              ]
            }
          }).results
        end

        def ignore_future
          matrix_parent_only.select do |item|
            item.last_modified_date.utc <= Time.now.utc
          end
        end

        def matrix_parent_only
          search.select { |item| item.matrix_type.nil? || item.matrix_type == "_parent" }
        end

        def last_updated_after
          Time.parse(config.fetch('netsuite.last_updated_after')).iso8601
        end
    end
  end
end
