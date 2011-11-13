class Song
  attr_accessor :name, :artist, :genre, :subgenre, :tags

  def initialize(name, artist, genre, subgenre, tags)
    @name = name
    @artist = artist
    @genre = genre
    @subgenre = subgenre
    @tags = tags
  end

  def matches?(criteria)
    results = []
    results << (criteria.fetch(:name, @name) == name)
    results << (criteria.fetch(:artist, @artist) == artist)
    tags = criteria.fetch(:tags, [])
    results << verify_tags(tags)
    results << criteria[:filter].(self) if criteria[:filter]
    results.all?
  end

  private

  def verify_tags(tags)
    tags = Array(tags)
    positive_tags = tags.reject { |tag| tag.end_with? '!'}
    negative_tags = tags.select { |tag| tag.end_with? '!' }.map(&:chop)
    contains_all_positive = @tags & positive_tags == positive_tags
    contains_no_negative = @tags & negative_tags == [] 
    contains_all_positive && contains_no_negative
  end
end

class Collection
  ArtistTags = {
      'John Coltrane' => %w[saxophone],
      'Bach' => %w[piano polyphony],
  }

  def initialize(songs_as_string, artist_tags = ArtistTags)
    @collection = parse_songs(songs_as_string, artist_tags)
  end

  def find(criteria)
    @collection.select {|song| song.matches? criteria }
  end
     
  private

  def parse_songs(songs_as_string, artist_tags)
    songs_strings = songs_as_string.lines.map(&:strip)
    songs = songs_strings.map { |song_line| construct_song(song_line) }
    songs = songs.map do |song| 
      song.tags += artist_tags.fetch(song.artist, []) 
      song
    end
  end

  def construct_song(song)
    name, artist, genres, tags = song.split(/\.\s*/).map(&:strip)
    genre, subgenre = genres.split(/,\s*/).map(&:strip)
    tags = tags || ""
    tags = tags.split(/,\s*/).map(&:strip)
    tags << genre.downcase
    tags << subgenre.downcase if subgenre
    Song.new(name, artist, genre, subgenre, tags)
  end
end
