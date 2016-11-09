#LET'S MAKE AN API THAT SERVES MESSAGES

#NEED THIS GEM
gem install rails-api


#TUTORIAL SAYS TO DO THIS, BUT DO WE NEED TO?
rails-api new mensajes --database=postgresql

#SET UP A DATABASE?  THIS SEEMS FAMILIAR...  BUT?
rake db:create

#SAYS TO OPEN UP THE MIGRATIONS AND SET EVERYTHING TO

null: false

#THEN
rake db:migrate


#CREATING MODELS WITH SCAFFOLDS...  HOW IS THAT DIFFERENT THAN A MODEL?  MUST RESEARCH SCAFFOLD
rails g scaffold user username:string
rails g scaffold message sender_id:integer recipient_id:integer body:text


#OK, RELATIONSHIPS!  BUT WHY IS THERE A CLASS?  OTHER STUFF MAKES SENSE
class User < ActiveRecord::Base
  has_many :sent_messages, class_name: "Message", foreign_key: "sender_id"
  has_many :received_messages, class_name: "Message", foreign_key: "recipient_id"
end

class Message < ActiveRecord::Base
  belongs_to :recipient, class_name: "User", inverse_of: :received_messages
  belongs_to :sender, class_name: "User", inverse_of: :sent_messages
end


#OK, FINDING OUR MESSAGES!

class User < ActiveRecord::Base

	def messages 

	@messages = Message.where("sender_id = ? OR recipient_id = ?", self.id, self.id) end 

end

#NOW WE RENDER THE MESSAGES IN JSON

class MessagesController < ApplicationController
  def index
    @messages = current_user.messages
    render json: @messages
  end
end

#IF WE LEAVE IT AT THAT, IT WON'T BE PRETTY.  THIS GEM WILL HELP

gem "active_model_serializers", github: "rails-api/active_model_serializers"


#MAKE A SERIALIZER TAHT WILL HELP US CARVE OUT JUST THE INFO WE WANT
rails g serializer message


#MAKE A NEW FILE?  OR IS IT MADE ALREADY.  NOT SURE.  ATTRIBUTES IN IT ARE RETURNED AS JSON.  HERE WE ONLY GET ID #s AND THE BODY OF THE MESSAGE
#app/serializers/message_serializer.rb,

class MessageSerializer < ActiveModel::Serializer
  attributes :sender_id, :recipient_id, :body
end

#WE CAN MAKE IT MORE SPECIFIC, DOING IT THIS WAY GIVES US A NESTED HASH THAT INCLUDES INFORMATION ABOUT THE SENDER/RECIPIENT LIKE USERNAME AND DATE/TIME CREATED  

class MessageSerializer < ActiveModel::Serializer
  attributes :sender, :recipient, :body
end

#AND WE CAN MAKE IT CLEANER AND MORE SPECIFIC IF WE MAKE A USER SERIALIZER


rails g serializer user

#HERE WE DEFINE THE ATTRIBUTES

class MessageSerializer < ActiveModel::Serializer
  attributes :body
  belongs_to :sender
  belongs_to :recipient
end

#TO LINK THE USERS TOGETHER BY THEIR CONVERSATIONS, WE NEED TO MAKE A CONVERSATION MODEL.  IT DOESN'T NEED TO BE AN ACTIVE RECORD MODEL, THOUGH.  SO...


# app/models/conversation.rb
class Conversation
  attr_reader :participant, :messages

  def initialize(attributes)
    @participant = attributes[:participant]
    @messages = attributes[:messages]
  end
end


#WE NEED A CONVERSATION CONTROLLER WHICH WE CAN DO IN THE MODEL (??).  IT'S JUST A METHOD IN THE MODEL BUT IT DOES THE THING

#ADD THIS TO MODEL(?).  IT'LL GROUP THE MESSAGES BY SENDER AND RECIPIENT.


  def self.for_user(user)
    user.messages.group_by { |message|
      if message.sender == user
        message.recipient_id
      else
        message.sender_id
      end
    }.map do |user_id, messages|
      Conversation.new({
        participant: User.find(user_id),
        messages: messages
      })
    end
  end
end

#WE NEED TO CONFIGURE ROUTES

#config/routes

Rails.application.routes.draw do
  ...
  resources :conversations, only: [:index]
end

#NOW WE MAKE A REAL CONTROLLER - NOT SURE WHY?

# app/controllers/conversations_controller.rb

class ConversationsController < ApplicationController
  def index
    conversations = Conversation.for_user(current_user)
    render json: conversations
  end
end

#GOING TO /conversations SHOULD GIVE US WHAT WE NEED, BUT WE HAVE TO MAKE A SERIALIZER FOR CONVERSATIONS OR WE'LL GET AN ERROR WITH THE "render json: conversations" PORTION 

rails g serializer conversation

#ADD ATTRIBUTES TO IT

class ConversationSerializer < ActiveModel::Serializer
  attributes :participant, :messages
end

#ADD A NOTE TO THE CONVERSATION MODEL SO IT DOESN'T THROW AN ERROR -- IT DOESN'T KNOW WHAT TO DO WITH IT ALL.  THE ALIAS WILL HELP.

class Conversation
  alias :read_attribute_for_serialization :send
  ...
end

#WE NEED TO CLEAN UP OUR CONVERSATIONS, SO WE MAKE CHANGES TO THE CONVERSATION SERIALIZER

class ConversationSerializer < ActiveModel::Serializer
  has_many :messages, class_name: "Message"
  belongs_to :participant, class_name: "User"
end

#BUT WE CAN'T SEE WHO THE SENDER WAS.  SO WE MAKE CHANGES TO THE MESSAGES SERIALIZER

class MessageSerializer < ActiveModel::Serializer
  attributes :body, :recipient, :sender

  def sender
    UserSerializer.new(object.sender).attributes
  end

  def recipient
    UserSerializer.new(object.recipient).attributes
  end
end

#CAN WE TEST THIS ON HEROKU????


















