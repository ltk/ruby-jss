# Copyright 2020 Pixar

#
#    Licensed under the Apache License, Version 2.0 (the "Apache License")
#    with the following modification; you may not use this file except in
#    compliance with the Apache License and the following modification to it:
#    Section 6. Trademarks. is deleted and replaced with:
#
#    6. Trademarks. This License does not grant permission to use the trade
#       names, trademarks, service marks, or product names of the Licensor
#       and its affiliates, except as required to comply with Section 4(c) of
#       the License and to reproduce the content of the NOTICE file.
#
#    You may obtain a copy of the Apache License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the Apache License with the above modification is
#    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#    KIND, either express or implied. See the Apache License for the specific
#    language governing permissions and limitations under the Apache License.
#
#

# The module
module Jamf

  # A Collection Resource in Jamf Pro
  #
  # See {Jamf::Resource} for general info about API resources.
  #
  # Collection resources have more than one resource within them, and those
  # can (usually) be created and deleted as well as fetched and updated.
  # The entire collection (or a part of it) can also be retrieved as an Array.
  # When the whole collection is retrieved, the result may be cached for future
  # use.
  #
  # # Subclassing
  #
  # ## Creatability, & Deletability
  #
  # Sometimes the API doesn't support creation of new members of the collection.
  # If that's the case, just extend the subclass with Jamf::UnCreatable
  # and the '.create' class method will raise an error.
  #
  # Similarly for deletion of members: if the API doesn't have a way to delete
  # them, extend the subclass with Jamf::UnDeletable
  #
  # See also Jamf::JSONObject, which talks about extending subclasses
  # with Jamf::Immutable
  #
  # ## Bulk Deletion
  #
  # Some collection resources have a resource for bulk deletion, passing in
  # a JSON array of ids to delete.
  #
  # If so, just define a BULK_DELETE_RSRC, and the .delete class method
  # will use it, rather than making multiple calls to delete individual
  # items. See Jamf::Category::BULK_DELETE_RSRC for an example
  #
  # @abstract
  #
  class CollectionResource < Jamf::Resource

    extend Jamf::BaseClass
    extend Jamf::Pageable
    extend Jamf::Sortable
    extend Jamf::Filterable

    include Comparable

    # Public Class Methods
    #####################################

    # @return [Array<Symbol>] the attribute names that are marked as identifiers
    #
    def self.identifiers
      self::OBJECT_MODEL.select { |_attr, deets| deets[:identifier] }.keys
    end

    def self.count(cnx: Jamf.cnx)
      collection_count(rsrc_path, cnx: Jamf.cnx)
    end


    # Get all instances of a CollectionResource, possibly limited by a filter.
    #
    # When called without specifying paged:, sort:, or filter: (see below)
    # this method will return a single Array of all items of its
    # CollectionResouce subclass, in the server's default sort order. This
    # full list is cached for future use (see Caching, below)
    #
    # However, the Array can be sorted by the server, filtered to contain only
    # matching objects, or 'paged', i.e. retrieved in successive Arrays of a
    # certain size.
    #
    # Sorting, filtering, and paging can all be used at the same time.
    #
    # #### Server-side Sorting
    #
    # Sorting criteria can be provided in the String format 'property:direction',
    # where direction is 'asc' or 'desc' E.g.
    #   "username:asc"
    #
    # Multiple properties are supported, either as separate strings in an Array,
    # or a single string, comma separated. E.g.
    #
    #    "username:asc,timestamp:desc"
    # is the same as
    #    ["username:asc", "timestamp:desc"]
    #
    # which will sort by username alphabetically, and within each username,
    # sort by timestamp newest first.
    #
    # Please see the JamfPro API documentation for the resource for details
    # about available sorting properties and default sorting criteria
    #
    # #### Filtering
    #
    # Some CollectionResouces support RSQL filters to limit which objects
    # are returned. These filters can be applied using the filter: parameter,
    # in which case this `all` method will return `all that match the filter`.
    #
    # If the resource doesn't support filters, the filter parameter is ignored.
    #
    # Please see the JamfPro API documentation for the resource to see if
    # filters are supported, and a list of available fields.
    #
    # #### Paging
    #
    # To reduce server load and local memory usage, you can request the results
    # in 'pages', i.e. successivly retrieved Arrays, using the paged: and page_size:
    # parameters.
    #
    # When paged: is truthy, the call to `all` returns the first group of objects
    # containing however many are specified by page_size: The default page size
    # is 100,  the minimum is 1, and the maximum is 2000.
    #
    # Once you have made a paged call to `all`, you must use the `next_page_of_all`
    # method to get the next Array of objects. That method merely repeats the last
    # request made by `all` after incrementing the page number by 1.
    # When `next_page_of_all` returns an empty array, you have retrieved all
    # availalble objects.
    #
    # `next_page_of_all` always reflects the last _paged_ call to `all`. Any
    # subsequent paged call to `all` will reset the paging process for that
    # collection class, and any unfinished previous paged calls to `all` will
    # be forgotten
    #
    # #### Instantiation
    #
    # All data from the API comes from the server in JSON format, mostly as
    # JSON 'objects', which are the equivalent of ruby Hashes.
    # When fetching an individual instance of an object from the API, ruby-jss
    # uses the JSON Hash to create the ruby object, i.e. to 'instantiate' it as
    # an instance of its class. Doing this for many objects can slow things down.
    #
    # Because of this, the 'all' method defaults to returning an Array of the
    # minimally-processed JSON Hashes it gets from the API. If you can get your
    # desired data from these Hashes, it's far more efficient to do so.
    #
    # However sometimes you really need the fully instantiated ruby objects for
    # all of them - especially if you're using filters and not actually processing
    # all items of the class.  In such cases you can pass a truthy value to the
    # instantiate: parameter, and the Array will contain fully instantiated
    # ruby objects, not Hashes of API data.
    #
    # #### Caching
    #
    # When called without specifying paged:, sort:, or filter:
    # this method will return a single Array of all items of its
    # CollectionResouce subclass, in the server's default sort order.
    #
    # This Array is cached in ruby-jss, and future calls to this method without
    # those parameters will return the cached Array. Use `refresh: true` to
    # re-request that Array from the server. Note that the cache is of the raw
    # JSON Hash data. Using 'instantiate:' will still be slower as each item in
    # the cache is instantiated. See 'Instantiation' above.
    #
    # Some other class methods, e.g. .all_names, will generate or use this cached
    # Array to derive their values.
    #
    # If any of the parameters paged:, sort:, or filter: are used, an API
    # request is made every time, and no caches are used or stored.
    #
    #######
    #
    # @param sort [String, Array<String>] Server-side sorting criteria in the
    #   format: property:direction, where direction is 'asc' or 'desc'. Multiple
    #   properties are supported, either as separate strings in an Array, or
    #   a single string, comma separated.
    #
    # @param filter [String] An RSQL filter string. Not all collection resources
    #   currently support filters, and if they don't, this will be ignored.
    #
    # @param paged [Boolean] Defaults to false. Returns only the first page of
    #   `page_size` objects. Use {.next_page_of_all} to retrieve each successive
    #   page.
    #
    # @param page_size [Integer] How many items are returned per page? Minimum
    #   is 1, maximum is 2000, default is 100. Ignored unless paged: is truthy.
    #   Note: the final page may contain fewer items than the page_size
    #
    # @param refresh [Boolean] re-fetch and re-cache the full list of all instances.
    #   Ignored if paged:, page_size:, sort:, filter: or instantiate: are used.
    #
    # @param instantiate [Boolean] Defaults to false. Should the items in the
    #   returned Array(s) be ruby instances of the CollectionObject subclass, or
    #   plain Hashes of data as returned by the API?
    #
    # @param cnx [Jamf::Connection] The API connection to use, default: Jamf.cnx
    #
    # @return [Array<Hash, Jamf::CollectionResource>] The objects in the collection
    #
    def self.all(sort: nil, filter: nil, paged: nil, page_size: nil, refresh: false, instantiate: false, cnx: Jamf.cnx)
      stop_if_base_class

      # use the cache if not paging, filtering or sorting
      return cached_all(refresh, instantiate, cnx) if !paged && !sort && !filter

      # we are sorting, filtering or paging
      sort = parse_collection_sort(sort)
      filter = parse_collection_filter(filter)

      result =
        if paged
          first_collection_page(rsrc_path, page_size, sort, filter, cnx)
        else
          fetch_all_collection_pages(rsrc_path, sort, filter, cnx)
        end
      instantiate ? result.map { |m| new m } : result
    end

    # PRIVATE
    # return the cached/cachable version of .all, possibly instantiated
    #
    # @param refresh [Boolean] refetch the cache from the server?
    #
    # @param instantiate [Boolean] Return an array of instantiated objects, vs
    #   JSON hashes?
    #
    # @param cnx [Jamf::Connection] The Connection to use
    #
    # @return [Array<Hash,Object>] All the objects in the collection
    #
    def self.cached_all(refresh, instantiate, cnx)
      cnx.collection_cache[self] = nil if refresh
      unless cnx.collection_cache[self]
        sort = nil
        filter = nil
        cnx.collection_cache[self] = fetch_all_collection_pages(rsrc_path, sort, filter, cnx)
      end
      instantiate ? cnx.collection_cache[self].map { |m| new m } : cnx.collection_cache[self]
    end
    private_class_method :cached_all


    # Fetch the next page of a paged .all request. See
    # {Jamf::Pagable.next_collection_page}
    def self.next_page_of_all
      next_collection_page
    end

    # An array of the ids for all collection members. According to the
    # specs ALL collection resources must have an ID, which is used in the
    # resource path.
    #
    # NOTE: This method uses the cached version of .all
    #
    # @param refresh (see .all)
    #
    # @param cnx (see .all)
    #
    # @return [Array<Integer>]
    #
    def self.all_ids(refresh = false, cnx: Jamf.cnx)
      all(refresh: refresh, cnx: cnx).map { |m| m[:id] }
    end

    # A Hash of all members of this collection where the keys are some
    # identifier and values are any other attribute.
    #
    # NOTE: This method uses the cached version of .all
    #
    # @param ident [Symbol] An identifier of this Class, used as the key
    #   for the mapping Hash. Aliases are acceptable, e.g. :sn for :serialNumber
    #
    # @param to [Symbol] The attribute to which the ident will be mapped.
    #   Aliases are acceptable, e.g. :name for :displayName
    #
    # @param refresh (see .all)
    #
    # @param cnx (see .all)
    #
    # @return [Hash {Symbol: Object}] A Hash of identifier mapped to attribute
    #
    def self.map_all(ident, to:, cnx: Jamf.cnx, refresh: false)
      real_ident = attr_key_for_alias ident
      raise Jamf::InvalidDataError, "No identifier #{ident} for class #{self}" unless
      identifiers.include? real_ident

      real_to = attr_key_for_alias to
      raise Jamf::NoSuchItemError, "No attribute #{to} for class #{self}" unless self::OBJECT_MODEL.key? real_to

      list = all refresh: refresh, cnx: cnx
      to_class = self::OBJECT_MODEL[real_to][:class]
      mapped = list.map do |i|
        [
          i[real_ident],
          to_class.is_a?(Symbol) ? i[real_to] : to_class.new(i[real_to])
        ]
      end # do i
      mapped.to_h
    end

    # Given a key (identifier) and value for this collection, return the raw data
    # Hash (the JSON object) for the matching API object or nil if there's no
    # match for the given value.
    #
    # In general you should use this if the form:
    #
    #    raw_data identifier: value
    #
    # where identifier is one of the available identifiers for this class
    # like id:, name:, serialNumber: etc.
    #
    # In the unlikely event that you dont know which identifier a value is for
    # or want to be able to take any of them without specifying, then
    # you can use
    #
    #   raw_data some_value
    #
    # If some_value is an integer or a string containing an integer, it
    # is assumed to be an :id otherwise all the available identifers
    # are searched, in the order you see them when you call <class>.identifiers
    #
    # If no matching object is found, nil is returned.
    #
    # Everything except :id is treated as a case-insensitive String
    #
    # @param value [String, Integer] The identifier value to search fors
    #
    # @param key: [Symbol] The identifier being used for the search.
    #  E.g. if :serialNumber, then the value must be a known serial number, it
    #  is not checked against other identifiers. Defaults to :id
    #
    # @param cnx: (see .all)
    #
    # @return [Hash, nil] the basic dataset of the matching object,
    #   or nil if it doesn't exist
    #
    def self.raw_data(value = nil, cnx: Jamf.cnx, **ident_and_val)
      stop_if_base_class

      # given a value with no ident key
      return raw_data_by_value_only(value, cnx: Jamf.cnx) if value

      # if we're here, we should know our ident key and value
      ident, value = ident_and_val.first
      raise ArgumentError, 'Required parameter "identifier: value", where identifier is id:, name: etc.' unless ident && value

      return raw_data_by_id(value, cnx: cnx) if ident == :id
      return unless identifiers.include? ident

      raw_data_by_other_identifier(ident, value, cnx: cnx)
    end

    # Match the given value in all possibly identifiers
    def self.raw_data_by_value_only(value, cnx: Jamf.cnx)
      return raw_data_by_id(value, cnx: cnx) if value.to_s.j_integer?

      identifiers.each do |ident|
        next if ident == :id

        data = raw_data_by_other_identifier(ident, value, cnx: cnx)
        return data if data
      end # identifiers.each
    end
    private_class_method :raw_data_by_value_only

    # get the basic dataset by id, with optional
    # request params to get more than basic data
    def self.raw_data_by_id(id, request_params: nil, cnx: Jamf.cnx)
      cnx.get "#{rsrc_path}/#{id}#{request_params}"
    rescue => e
      return if e.httpStatus == 404

      raise e
    end
    private_class_method :raw_data_by_id

    # Given an indentier attr. key, and a value,
    # return the raw data where that ident has that value, or nil
    #
    def self.raw_data_by_other_identifier(identifier, value, refresh: true, cnx: Jamf.cnx)
      # if the API supports filtering by this identifier, just use that
      return all(filter: "#{identifier}=='#{value}'", paged: true, page_size: 1, cnx: cnx).first if self::OBJECT_MODEL[identifier][:filter_key]

      # otherwise we have to loop thru all the objects looking for the value
      all(refresh: refresh, cnx: cnx).each { |data| return data if data[identifier].to_s.casecmp? value.to_s }

      nil
    end
    private_class_method :raw_data_by_other_identifier

    # Look up the valid ID for any arbitrary identifier.
    # In general you should use this if the form:
    #
    #    valid_id identifier: value
    #
    # where identifier is one of the available identifiers for this class
    # like id:, name:, serialNumber: etc.
    #
    # In the unlikely event that you dont know which identifier a value is for
    # or want to be able to take any of them without specifying, then
    # you can use
    #
    #   valid_id some_value
    #
    # If some_value is an integer or a string containing an integer, it
    # is assumed to be an id: otherwise all the available identifers
    # are searched, in the order you see them when you call <class>.identifiers
    #
    # If no matching object is found, nil is returned.
    #
    # WARNING: Do not use this to look up ids for getting the
    # raw API data for an object. Since this calls .raw_data
    # itself, it is redundant to use .valid_id to get an id
    # to then pass on to .raw_data
    # Use raw_data directly like this:
    #    data = raw_data(ident: val)
    #
    #
    # @param value [String,Integer] A value for an arbitrary identifier
    #
    # @param cnx [Jamf::Connection] The connection to use. default: Jamf.cnx
    #
    # @param ident_and_val [Hash{Symbol: String}] The identifier key and the value
    #   to look for in that key, e.g. name: 'foo' or serialNumber: 'ASDFGH'
    #
    # @return [String, nil] The id (integer-in-string) of the object, or nil
    #    if no match found
    #
    def self.valid_id(value = nil, cnx: Jamf.cnx, **ident_and_val)
      raw_data(value, cnx: cnx, **ident_and_val)&.dig(:id)
    end

    # Bu default, subclasses are creatable, i.e. new instances can be created
    # with .create, and added to the JSS with .save
    # If a subclass is NOT creatble for any reason, just add
    #   extend Jamf::UnCreatable
    # and this method will return false
    #
    # @return [Boolean]
    def self.creatable?
      true
    end

    # Make a new thing to be added to the API
    def self.create(**params)
      stop_if_base_class

      raise Jamf::UnsupportedError, "#{self}'s are not currently creatable via the API" unless creatable?

      # Which connection to use
      cnx = params.delete :cnx
      cnx ||= Jamf.cnx

      params.delete :id # no such animal when .creating
      params.keys.each do |param|
        raise ArgumentError, "Unknown parameter: #{param}" unless self::OBJECT_MODEL.key? param

        if params[param].is_a? Array
          params[param].map! { |val| validate_attr param, val, cnx: cnx }
        else
          params[param] = validate_attr param, params[param], cnx: cnx
        end
      end

      params[:creating_from_create] = true
      new params, cnx: cnx
    end

    # Retrieve a member of a CollectionResource from the API
    #
    # To create new members to be added to the JSS, use
    # {Jamf::CollectionResource.create}
    #
    # You must know the specific identifier attribute you're looking up, e.g.
    # :id or :name or :udid, (or an aliase thereof) then you can specify it like
    # `.fetch name: 'somename'`, or `.fetch udid: 'someudid'`
    #
    # @param cnx[Jamf::Connection] the connection to use to fetch the object
    #
    # @param ident_and_val[Hash] an identifier attribute key and a search value
    #
    # @return [CollectionResource] The ruby-instance of a Jamf object
    #
    def self.fetch(random = nil, cnx: Jamf.cnx, **ident_and_val)
      stop_if_base_class
      ident, value = ident_and_val.first
      data =
        if random
          all.sample
        elsif ident && value
          raw_data(cnx: cnx, **ident_and_val)
        end
      raise Jamf::NoSuchItemError, "No matching #{self}" unless data

      new data, cnx: cnx
    end # fetch

    # By default, CollectionResource subclass instances are deletable.
    # If not, just extend the subclass with Jamf::UnDeletable, and this
    # will return false, and .delete & #delete will raise errors
    def self.deletable?
      true
    end

    # Delete one or more objects by id
    #
    # @param ids [Array<String,Integer>] The ids to delete
    #
    # @param cnx [Jamf::Connection] The connection to use, default: Jamf.cnx
    #
    # @return [Array<Jamf::Connection::APIError::ErrorInfo] Info about any ids
    #   that failed to be deleted.
    #
    def self.delete(*ids, cnx: Jamf.cnx)
      raise Jamf::UnsupportedError, "Deleting #{self} objects is not currently supported" unless deletable?

      return bulk_delete(ids, cnx: Jamf.cnx) if ancestors.include? Jamf::BulkDeletable

      errs = []
      ids.each do |id_to_delete|
        begin
          cnx.delete "#{rsrc_path}/#{id_to_delete}"
        rescue Jamf::Connection::APIError => e
          raise e unless e.httpStatus == 404

          errs += e.errors
        end # begin
      end # ids.each
      errs
    end

    # Private Class Methods
    #####################################

    # TODO: better pluralizing?
    #
    def self.create_list_methods(attr_name, attr_def)
      list_method_name = "all_#{attr_name}s"

      define_singleton_method(list_method_name) do |refresh = false, cnx: Jamf.cnx|
        all_list = all(refresh: refresh, cnx: cnx)
        if attr_def[:class].is_a? Symbol
          all_list.map { |i| i[attr_name] }.uniq
        else
          all_list.map { |i| attr_def[:class].new i[attr_name] }
        end
      end # define_singleton_method

      return unless attr_def[:aliases]

      # aliases - TODO: is there a more elegant way?
      attr_def[:aliases].each do |a|
        define_singleton_method("all_#{a}s") do |refresh = false, cnx: Jamf.cnx|
          send list_method_name, refresh, cnx: cnx
        end # define_singleton_method
      end # each alias
    end # create_list_methods
    private_class_method :create_list_methods


    # Instance Methods
    #####################################

    def exist?
      !@id.nil?
    end

    def rsrc_path
      return unless exist?

      "#{self.class.rsrc_path}/#{@id}"
    end

    def delete
      raise Jamf::UnsupportedError, "Deleting #{self} objects is not currently supported" unless self.class.deletable?

      @cnx.delete rsrc_path
    end

    # Two collection resource objects are the same if their id's are the same
    def <=>(other)
      id <=> other.id
    end

    # Private Instance Methods
    ############################################
    private

    def create_in_jamf
      result = @cnx.post self.class.rsrc_path, to_jamf
      @id = result[:id]
    end

  end # class CollectionResource

end # module JAMF
