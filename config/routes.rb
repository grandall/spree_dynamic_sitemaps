Rails.application.routes.draw do

	resources :sitemap, :constraints => { :format => /xml/ }

end
