require 'test_helper'

class VideosControllerTest < ActionDispatch::IntegrationTest
  describe "index" do
    it "returns a JSON array" do
      get videos_url
      assert_response :success
      expect(@response.headers['Content-Type']).must_include 'json'

      # Attempt to parse
      data = JSON.parse @response.body
      expect(data).must_be_kind_of Array
    end

    it "should return many video fields" do
      get videos_url
      assert_response :success

      data = JSON.parse @response.body
      data.each do |video|
        expect(video).must_include "title"
        expect(video).must_include "release_date"
      end
    end

    it "returns all videos when no query params are given" do
      get videos_url
      assert_response :success

      data = JSON.parse @response.body
      expect(data.length).must_equal Video.count

      expected_names = {}
      Video.all.each do |video|
        expected_names[video["title"]] = false
      end

      data.each do |video|
        expect(
          expected_names[video["title"]]
        ).must_equal false, "Got back duplicate video #{video["title"]}"

        expected_names[video["title"]] = true
      end
    end
  end

  describe "show" do
    it "Returns a JSON object" do
      get video_url(title: videos(:one).title)
      assert_response :success
      expect(@response.headers['Content-Type']).must_include 'json'

      # Attempt to parse
      data = JSON.parse @response.body
      expect(data).must_be_kind_of Hash
    end

    it "Returns expected fields" do
      get video_url(title: videos(:one).title)
      assert_response :success

      video = JSON.parse @response.body
      expect(video).must_include "title"
      expect(video).must_include "overview"
      expect(video).must_include "release_date"
      expect(video).must_include "inventory"
      expect(video).must_include "available_inventory"
    end

    it "Returns an error when the video doesn't exist" do
      get video_url(title: "does_not_exist")
      assert_response :not_found

      data = JSON.parse @response.body
      expect(data).must_include "errors"
      expect(data["errors"]).must_include "title"
    end
  end

  describe "create" do
    before do
      # Arrange
      @video_hash = {
        title: "the l3go movie",
        overview: "it IS getting a trequel, right?",
        release_date: "2022-04-30",
        inventory: 10,
        external_id: 10,
        image_url: "https://www.themoviedb.org/t/p/w1280/lbctonEnewCYZ4FYoTZhs8cidAl.jpg"
      }
    end
    it "can create a valid video" do
      # Assert
      expect {
        post videos_path, params: @video_hash
      }.must_change "Video.count", 1

      must_respond_with :created
    end

    it "will respond with bad request and errors for an invalid movie" do
      # Arrange
      @video_hash[:external_id] = 7 # match external id of fixture

      # Assert
      expect {
        post videos_path, params: @video_hash
      }.wont_change "Video.count"
      body = JSON.parse(response.body)

      expect(body.keys).must_include "errors"
      expect(body["errors"].keys).must_include "external_id"
      expect(body["errors"]["external_id"]).must_include "has already been taken"

      must_respond_with :bad_request
    end

  end
end
