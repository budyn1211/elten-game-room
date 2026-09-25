class PrivateArchiveDouble
  Resource = Struct.new(:id, :resource, :uploader, :filesize, :meta, keyword_init: true)
  attr_reader :used_size
  attr_accessor :quota, :lost_reply, :corrupt, :write_error, :lost_delete_reply
  def initialize; @items = {}; @data = {}; @quota = 16 * 1024 * 1024; end
  def list(timeout:); @used_size = @data.values.sum(&:bytesize); @items.values; end
  def max_private_resources_bytes_per_user; @quota; end
  def upload(name, data, meta:, timeout:)
    raise IOError, 'upload denied' if write_error
    id = @items.keys.max.to_i + 1
    @data[id] = data
    row = @items[id] = Resource.new(id: id, resource: name, uploader: 'Alice', filesize: data.bytesize, meta: meta)
    raise IOError, 'lost reply' if lost_reply
    row
  end
  def download(id, timeout:); corrupt ? 'broken' : @data.fetch(id); end
  def delete(id, timeout:)
    @items.delete(id)
    @data.delete(id)
    raise IOError, 'lost delete reply' if lost_delete_reply
  end
end
