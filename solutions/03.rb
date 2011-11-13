require 'bigdecimal'
require 'bigdecimal/util'

class Inventory

  def initialize()
    @products = []
    @coupons = []
  end

  def register(product_name, price, promotion = {})
    price = price.to_d
    verify_product product_name, price
    promotion = Promotions.for promotion
    @products << Product.new(product_name, price, promotion)
  end

  def new_cart()
    Cart.new self
  end

  def [](name)
    @products.detect { |product| product.name == name }
  end

  def register_coupon(name, description)
    @coupons << Coupons.build(name, description)
  end

  def get_coupon(name)
    @coupons.detect { |coupon| coupon.name == name } or Coupon::NilCoupon.new  
  end

  private

  def verify_product(product_name, price)
    if self[product_name] or product_name.length > 40
      raise "Bad name."
    elsif price < 0.01 or price > 999.99
      raise "Bad price"
    end
  end
end

class Cart
  
  attr_reader :products, :coupon

  def initialize(inventory)
    @products = Hash.new 0
    @inventory = inventory 
    @coupon = Coupons::NilCoupon.new
  end

  def add(product_name, number = 1)
    product_to_add = @inventory[product_name] or raise "Bad name"
    new_count = @products[product_to_add] + number
    if number <= 0 or new_count > 99
      raise "Number invalid."
    end
    @products[product_to_add] = new_count
  end

  def items_price
    @products.inject(0) do |total, (product, count)| 
      total + product.discounted_price(count)
    end
  end
  
  def total
    items_price - coupon_discount
  end

  def coupon_discount
    @coupon.discount items_price
  end

  def invoice
    printer = InvoicePrinter.new self
    printer.invoice
  end

  def use(coupon_name)
    @coupon = @inventory.get_coupon(coupon_name)
  end
end

class Product
  
  attr_accessor :name, :price, :promotion

  def initialize(name, price, promotion)
    @name = name
    @price = price
    @promotion = promotion
  end

  def discounted_price(count)
      @price * count - discount(count)
  end

  def discount(count)
    @promotion.discount self, count
  end
 
  def discount_string(count)
    @promotion.discount_string
  end

end

class InvoicePrinter

  def initialize(cart)
    @cart = cart
  end

  def invoice
    invoice = header
    @cart.products.each { |product, count| invoice << get_line(product, count)}
    if @cart.coupon_discount > 0
      discount = @cart.coupon_discount
      coupon_string = @cart.coupon.coupon_string
      invoice << format("| %-46s |%9.2f |\n", coupon_string, -discount)
    end
    invoice << total
  end

  private 

  def header
    header_s = line_separator
    header_s << format("| %-42s qty |    price |\n", "Name")
    header_s << line_separator
  end

  def total
    total_s = line_separator
    total_s << format("| %-46s |%9.2f |\n", "TOTAL", @cart.total)
    total_s << line_separator
  end

  def line_separator
    "+------------------------------------------------+----------+\n"
  end

  def get_line(product, count)
    format_s = "| %-44s%2d |%9.2f |\n"
    line = format format_s, product.name, count, product.price * count
    if product.discount(count) > 0 
      discount = -product.discount(count)
      discount_string = '(' + product.discount_string(count) + ')'
      line << format("|   %-45s|%9.2f |\n", discount_string, discount)
    end
    line
  end
end

module Promotions

  def self.for(hash)
    name, options = hash.first

    case name
      when :get_one_free then GetOneFreePromotion.new options
      when :package then PackagePromotion.new options
      when :threshold then ThresholdPromotion.new options
      else NoPromotion.new
    end
  end

  class GetOneFreePromotion

    def initialize(nth_free)
      @nThFree = nth_free
    end
 
    def discount(product, count)
      product.price * (count / @nThFree)
    end

    def discount_string
      format "buy %d, get 1 free", @nThFree - 1
    end

  end

  class PackagePromotion

    def initialize(hash)
      @packageSize, @discount = hash.first
    end

    def discount(product, count)
      (count / @packageSize) * @packageSize * product.price * @discount / 100
    end

    def discount_string
      format "get %d%% off for every %d", @discount, @packageSize
    end
  end

  class ThresholdPromotion

    def initialize(hash)
      @fullPriceNum, @discount = hash.first
    end

    def discount(product, count)
      [count - @fullPriceNum, 0].max * product.price * @discount / 100
    end
 
    def discount_string
      tail = case @fullPriceNum
               when 1 then "st"
               when 2 then "nd"
               when 3 then "rd"
             else "th"
             end
      format "%d%% off of every after the %d%s", @discount, @fullPriceNum, tail
    end
  end

  class NoPromotion
  
    def discount(count, price)
      0
    end

    def discount_string
      ''
    end
  end
end

module Coupons

  def self.build(name,type)
    case type.keys.first
      when :percent then PercentOff.new name, type[:percent]
      when :amount  then AmountOff.new  name, type[:amount].to_d
      else NilCoupon.new
    end
  end

  class AmountOff
    attr_reader :name

    def initialize(name, amount)
      @name = name
      @amount = amount
    end

    def discount(order_price)
      [order_price, @amount].min
    end

    def coupon_string
      discount = format "%.2f",  @amount
     "Coupon #{@name} - #{discount} off"
    end
  end

  class PercentOff

    attr_reader :name

    def initialize(name, percent)
      @name = name
      @percent = percent
    end

    def discount(order_price)
      (@percent / '100'.to_d) * order_price
    end
    
    def coupon_string
     "Coupon #{@name} - #{@percent}% off"
    end
  end

  class NilCoupon

    def discount(order_price)
      0
    end

    def coupon_string
      ''
    end

    def name 
      ''
    end

  end
end
