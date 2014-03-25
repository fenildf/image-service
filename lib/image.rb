require "./lib/image_uploader"
require "./lib/workers"
require "backgrounder/orm/activemodel"

class Image
  include Mongoid::Document
  include Mongoid::Timestamps
  extend CarrierWave::Backgrounder::ORM::ActiveModel

  field :file,     type: String
  field :original, type: String
  field :token,    type: String
  field :versions, type: Array
  field :file_processing, type: Boolean
  field :file_tmp, type: String

  validate :file, :original, :filename, presence: true

  mount_uploader :file, ImageUploader

  process_in_background :file, ProcessWorker
  store_in_background   :file, StoreWorker

  alias :old_vers :versions

  def self.from_params(hash)
    ImageUploader.apply_settings!
    image = self.new(token: randstr, original: hash[:filename])
    image.file = hash[:tempfile]
    image.versions = image.file.version_names
    image.save
    image
  end

  def filename
    "#{token}#{File.extname(original).downcase}"
  end

  def versions
    old_vers.map do |version|
      array = version.to_s.split("_")
      name  = array.select {|i| i.match /[a-zA-Z]+/}.join("_").to_sym
      value = array.select {|i| i.match /[0-9]+/}.map(&:to_i)
      {name: name, value: value, url: url_template(version)}
    end
  end

  private

  def url_template(version)
    base = file.url.split("/")[0..-2].join("/")
    File.join(base, "#{version}_#{filename}")
  end
end
