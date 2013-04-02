class SitemapController < Spree::BaseController
  def index
    @public_dir = root_url
    respond_to do |format|
      format.xml do
        render :layout => false, :xml => _build_xml(@public_dir)
      end
    end
  end

  private
  def _build_xml(public_dir)
    String.new.tap do |output|
      xml = Builder::XmlMarkup.new(:target => output, :indent => 2) 
      xml.instruct!  :xml, :version => "1.0", :encoding => "UTF-8"
      xml.urlset( :xmlns => "http://www.sitemaps.org/schemas/sitemap/0.9" ) {
        xml.url {
          xml.loc public_dir
          xml.lastmod Date.today
          xml.changefreq 'daily'
          xml.priority '1.0'
        }
        Spree::Taxonomy.navigation do |taxonomy|
          Spree::Taxon.find_in_batches(:condition => [:taxonomy_id => taxonomy.id]) do |group|
            group.each do |taxon|
              v = _build_taxon_hash(taxon)
              xml.url {
                xml.loc public_dir + v['link']
                xml.lastmod v['updated'].xmlschema			  #change timestamp of last modified
                xml.changefreq 'weekly'
                xml.priority '0.8'
              } 
            end
          end
        end
        #Spree::Product.active.find_in_batches do |group|
        #  group.each do |product|
        #    v = _build_product_hash(product)
        #    xml.url {
        #      xml.loc public_dir + v['link']
        #      xml.lastmod v['updated'].xmlschema			  #change timestamp of last modified
        #      xml.changefreq 'weekly'
        #      xml.priority '0.8'
        #    } 
        #  end
        #end
        Spree::Product.active.includes(:variants, :taxons).find_in_batches do |batch|
          batch.each do |product|
            product.variants.each do |variant|
              next unless variant.active?
              next unless variant.manufacturer_number.present?
              v = _build_variant_hash(product, variant)
              xml.url {
                xml.loc public_dir + v['link']
                xml.lastmod v['updated'].xmlschema			  #change timestamp of last modified
                xml.changefreq 'weekly'
                xml.priority '0.8'
              }
            end
          end
        end
        
        #ActiveRecord::Base.connection.select_all(<<-END
        #  select distinct replace(t.permalink, 'manufacturers/','skus/') as permalink, v.manufacturer_number, p.updated_at
        #  from spree_products p
        #    inner join spree_products_taxons pt
        #      on pt.product_id = p.id
        #    inner join spree_taxons t 
        #      on t.id = pt.taxon_id
        #    inner join spree_taxonomies tn 
        #      on tn.id = t.taxonomy_id
        #        and tn.name = 'Manufacturers'
        #    inner join spree_variants v 
        #      on v.product_id = p.id
        #        and v.deleted_at is null
        #        and p.deleted_at is null
        #        and v.is_master = 0
        #        and v.manufacturer_number is not null;
        #END
        #).each do |row|
        #  xml.url {
        #    xml.loc public_dir + row['permalink'] + "/#{CGI.escape(row['manufacturer_number'])}"
        #    xml.lastmod row['updated_at'].xmlschema
        #    xml.changefreq 'weekly'
        #    xml.priority '0.8'
        #  }
        #end
        
      }
    end
  end

  def _build_taxon_hash(taxon)
    tinfo = {}
    tinfo['name'] = taxon.name
    tinfo['depth'] = taxon.permalink.split('/').size
    tinfo['link'] = 't/' + taxon.permalink 
    tinfo['updated'] = taxon.updated_at
    tinfo
  end

  def _build_product_hash(product)
    pinfo = {}
    pinfo['name'] = product.name
    pinfo['link'] = 'products/' + product.permalink	# primary
    pinfo['updated'] = product.updated_at
    pinfo
  end

  def _build_variant_hash(variant)
    product = variant.product
    vinfo = {}
    vinfo['name'] = product.name + ' (' + variant.manufacturer_number + ')'
    vinfo['link'] = ['skus', product.manufacturer.permalink.split('/').last, variant.manufacturer_number].join('/')
    vinfo['updated'] = product.updated_at
    vinfo
  end
  
end
