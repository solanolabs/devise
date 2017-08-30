require 'test_helper'

class RememberableTest < ActiveSupport::TestCase
  def resource_class
    User
  end

  def create_resource
    create_user
  end

  test 'remember_me should not generate a new token if using salt' do
    user = create_user
    user.expects(:valid?).never
    user.remember_me!
    assert user.remember_created_at
  end

  test 'forget_me should not clear remember token if using salt' do
    user = create_user
    user.remember_me!
    user.expects(:valid?).never
    user.forget_me!
  end

  test 'serialize into cookie' do
    user = create_user
    user.remember_me!
    id, token, date = User.serialize_into_cookie(user)
    assert_equal id, user.to_key
    assert_equal token, user.authenticatable_salt
    assert date.is_a?(Time)
  end

  test 'serialize from cookie' do
    user = create_user
    user.remember_me!
    assert_equal user, User.serialize_from_cookie(user.to_key, user.authenticatable_salt, Time.now.utc)
  end

  test 'serialize from cookie should return nil if no resource is found' do
    assert_nil resource_class.serialize_from_cookie([0], "123", Time.now.utc)
  end

  test 'serialize from cookie should return nil if no timestamp' do
    user = create_user
    user.remember_me!
    assert_nil User.serialize_from_cookie(user.to_key, user.authenticatable_salt)
  end

  test 'serialize from cookie should return nil if timestamp is earlier than token creation' do
    user = create_user
    user.remember_me!
    assert_nil User.serialize_from_cookie(user.to_key, user.authenticatable_salt, 1.day.ago)
  end

  test 'serialize from cookie should return nil if timestamp is older than remember_for' do
    user = create_user
    user.remember_created_at = 1.month.ago
    user.remember_me!
    assert_nil User.serialize_from_cookie(user.to_key, user.authenticatable_salt, 3.weeks.ago)
  end

  test 'serialize from cookie me return nil if is a valid resource with invalid token' do
    user = create_user
    user.remember_me!
    assert_nil User.serialize_from_cookie(user.to_key, "123", Time.now.utc)
  end

  test 'raises a RuntimeError if authenticatable_salt is nil' do
    user = User.new
    user.encrypted_password = nil
    assert_raise RuntimeError do
      user.rememberable_value
    end
  end

  test 'should respond to remember_me attribute' do
    assert resource_class.new.respond_to?(:remember_me)
    assert resource_class.new.respond_to?(:remember_me=)
  end

  test 'forget_me should clear remember_created_at' do
    resource = create_resource
    resource.remember_me!
    assert_not resource.remember_created_at.nil?
    resource.forget_me!
    assert resource.remember_created_at.nil?
  end
  
  test 'forget_me should not try to update resource if it has been destroyed' do
    resource = create_resource
    resource.destroy
    resource.expects(:remember_created_at).never
    resource.expects(:save).never
    resource.forget_me!
  end

  test 'remember expires at uses remember for configuration' do
    swap Devise, :remember_for => 3.days do
      resource = create_resource
      resource.remember_me!
      assert_equal 3.days.from_now.to_date, resource.remember_expires_at.to_date

      Devise.remember_for = 5.days
      assert_equal 5.days.from_now.to_date, resource.remember_expires_at.to_date
    end
  end
end
