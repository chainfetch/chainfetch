class Public::BaseController < ApplicationController
  allow_unauthenticated_access
  layout "public"
end