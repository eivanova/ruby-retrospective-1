class Array
  def to_hash
    hash = {}
    each { |pair| hash[pair.first] = pair[1]}
    hash
  end

   def index_by
     #nice... 
     map { |n| [yield(n), n] }.to_hash
   end

   def subarray_count(subarray)
     each_cons(subarray.length).count(subarray)
   end

   def occurences_count
     hash = Hash.new { |key, value| 0 }
     each {|item| hash[item] = count(item)}
     hash
    end
end
