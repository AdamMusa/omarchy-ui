# frozen_string_literal: true

module OmarchyUI
  PROTOCOL_VERSION = 1
  MAX_MESSAGE_BYTES = 1_048_576
  VALID_ID = /\A[a-zA-Z0-9_.:-]{1,128}\z/
  VALID_EVENT = /\A[a-z][a-z0-9_]{0,63}\z/

  class ProtocolError < StandardError; end
end
