require 'httpi'
require 'diskcached'
require 'similar_text'
require 'json'

class GeoNames
  URL='http://api.geonames.org/searchJSON'

  def initialize(args = {})
    @default_country = args[:default_country]
    @username = args[:geonames_username]
    cache_expiration_time = args[:cache_expiration_time] || 7200
    @cache=Diskcached.new('/tmp/cache',cache_expiration_time,true)
  end

  def search_in_place(place,name,fcode,children_fcode,country,field_to_compare)
    country ||= @default_country

    points = []
    children_places = []
    place ||= {}

    children_fcode ||= case fcode
                         when 'PCLI' then 'ADM1'
                         when 'ADM1' then 'ADM2'
                         when 'ADM2' then 'ADM3'
                         when 'ADM3' then 'ADM4'
                         when 'ADM4' then 'ADM5'
                         when 'PPLC' then 'PPLX'
                       end

    field_to_compare ||= case fcode
                           when 'PCLI' then :countryCode
                           when 'ADM1' then :adminCode1
                           when 'ADM2' then :adminCode2
                           when 'ADM3' then :adminCode3
                         end

    if place.empty?
      fetch_geonames(name,country,nil,nil).each{|g|
        if g[:fcode]==fcode
          place[:name]=g[:name]
          place[:id]=g[:geonameId]
          place[field_to_compare]=g[field_to_compare]
          break
        end
      }
    end

    # Lookup for children and points
    fetch_geonames(name,country,field_to_compare.to_s,place[field_to_compare]).each{|g|
        points.push({:lon=>g[:lng],:lat=>g[:lat]})
        if g[:fcode] == children_fcode
          children_places.push({:name=>g[:name],:id=>g[:geonameId],:fcode=>g[:fcode],:country=>g[:countryCode]})
        end
    }

    {:children_places=>children_places,:place=>place,:points=>points}
  end

  private
  def fetch_geonames(name,country,admin_code_type,admin_code)
    admin_code_str = admin_code ? "&#{admin_code_type}=#{admin_code}" : ''

    @cache.cache("geonames_name=#{name}&country=#{country}#{admin_code_str}&full") do
      url = URI.escape("#{URL}?q=#{name}&country=#{country}#{admin_code_str}&style=FULL&order_by=relevance&maxRows=1000&username=#{@username}")
      request = HTTPI::Request.new(url)
      data = HTTPI.get(request)
      JSON.parse(data.body,:symbolize_names=>true)[:geonames]
    end
  end
end