# Copyright 2015, Google, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "google/cloud/storage"

# [START book]
class Book < ActiveRecord::Base

  def self.storage_bucket
    @storage_bucket ||= begin
      config = Rails.application.config.x.settings
      storage = Google::Cloud::Storage.new project_id: config["project_id"],
                                           credentials: config["keyfile"]
      storage.bucket config["gcs_bucket"]
    end
  end

  validates :title, presence: true

  attr_accessor :cover_image

  private

  # [START upload]
  after_create :upload_image, if: :cover_image

  def upload_image
    file = Book.storage_bucket.create_file \
      cover_image.tempfile,
      "cover_images/#{id}/#{cover_image.original_filename}",
      content_type: cover_image.content_type,
      acl: "public"

    update_columns image_url: file.public_url
  end
  # [END upload]

  # TODO what if the image is from the Pub/Sub job and NOT in Cloud Storage!?

  # [START delete]
  before_destroy :delete_image, if: :image_url

  def delete_image
    image_uri = URI.parse image_url

    if image_uri.host == "#{Book.storage_bucket.name}.storage.googleapis.com"
      # Remove leading forward slash from image path
      # The result will be the image key, eg. "cover_images/:id/:filename"
      image_path = image_uri.path.sub("/", "")

      file = Book.storage_bucket.file image_path
      file.delete
    end
  end
  # [END delete]

  # [START update]
  before_update :update_image, if: :cover_image

  def update_image
    delete_image if image_url?
    upload_image
  end
  # [END update]
end
# [END book]
