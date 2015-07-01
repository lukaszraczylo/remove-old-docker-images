#!/usr/bin/env ruby
# Cleaning docker images, with bits of charm and magic
require 'chronic'
require 'docker'

ENV['DOCKER_URL'] = 'unix:///var/run/docker.sock'
Excon.defaults[:ssl_verify_peer] = false

# Number of latest images which we want to always keep ( ignores "KEEP_IMAGES_FOR" variable )
KEEP_LAST_IMAGES = 2
# How old images should we remove
KEEP_IMAGES_FOR = "2 weeks"
# whitelisted images which should be kept
SAFE_IMAGES = [ /ubuntu/i, /postgres/i, /postgis/i, /rattic/i, /ruby/i ]

class DockerCleaner
  def initialize
    Docker.connection
    Docker.options[:read_timeout] = 360
    $d_images = get_list_of_images
    group_images
    delete_images
  end

  def delete_images
    puts 'delete images'
    re = Regexp.union(SAFE_IMAGES)
    $d_images.each do |img|
     begin
      if img[1].count > KEEP_LAST_IMAGES && ! img[0].match(re) && img[0].to_s != "<none>"
  d = img[1].count
  img[1] = img[1].drop(KEEP_LAST_IMAGES)
        img[1].each do |i|
   if i['created'].to_i < Chronic.parse("#{KEEP_IMAGES_FOR} ago").to_i
     puts "Removing: #{Time.at(i['created']).strftime("%F").to_s} - #{img[0]}:#{i['version']}"
     puts i['id']
     image = Docker::Image.get(i['id'])
     image.remove
         end
  end
      end
     rescue
      puts "error occured, skipping"
     end
    end
  end

  def group_images
    puts 'group images'
    tmp = Hash.new
    out = Array.new
    $d_images.each do |i|
  tag_base = i['tags'].split(':')
  if ! tmp.has_key?(tag_base[0])
    tmp[tag_base[0]] = Array.new
  end
        tmp[tag_base[0]].push(
    {
        'version' => tag_base[1],
        'id' => i['id'],
        'created' => i['created']
    })
    end
    tmp.each do |img|
      img[1] = img[1].sort_by { |h| h['created'] }.reverse!
      out.push(img)
    end
    $d_images = out
  end

  def get_list_of_images
    puts 'get list of images'
    images = Docker::Image.all
    results = Array.new
    # checking which images can be deleted
    images.each do |img|
      results.push(
        'id' => img.id,
  'created' => img.info['Created'],
  'tags' => img.info['RepoTags'][0],
      )
    end
    return results
  end
end

DockerCleaner.new
