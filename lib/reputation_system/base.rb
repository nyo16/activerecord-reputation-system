##
#  Copyright 2012 Twitter, Inc
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
##

module ReputationSystem
  module Base
    def self.included(klass)
      klass.extend ClassMethods
    end

    def get_attributes_of(reputation)
      of = reputation[:of]
      attrs = reputation[:of] == :self ? self : self.instance_eval(of.to_s) if of.is_a?(String) || of.is_a?(Symbol)
      attrs = self.instance_exec(self, &of) if of.is_a?(Proc)
      attrs = [attrs] unless attrs.is_a? Array
      attrs
    end

    def evaluate_reputation_scope(scope)
      if scope
        if self.respond_to? scope
          self.send(scope)
        else
          scope
        end
      end
    end

    module ClassMethods
      def has_reputation(reputation_name, options)
        has_valid_input = reputation_name && options[:aggregated_by] && options[:source]

        raise ArgumentError, "has_reputation method received invalid arguments." unless has_valid_input
        # Overwrites reputation if the same reputation name is declared in the same model.
        # TODO: This should raise exception instead while allowing Rails app to reload in dev mode.
        ReputationSystem::Network.remove_reputation_def(name, reputation_name) if has_reputation_for?(reputation_name)

        # If it is first time to be called
        unless ancestors.include?(ReputationSystem::Reputation)
          has_many :reputations, :as => :target, :class_name => "RSReputation", :dependent => :destroy
          include ReputationSystem::Query
          include ReputationSystem::Normalization
          include ReputationSystem::Reputation
          include ReputationSystem::Scope
        end

        ReputationSystem::Network.add_reputation_def(name, reputation_name, options)

        # evaluation related methods are defined only for primary reputations
        include ReputationSystem::Evaluation if ReputationSystem::Network.is_primary_reputation?(name, reputation_name) && !ancestors.include?(ReputationSystem::Evaluation)
      end

      def has_reputation_for?(reputation_name)
        ReputationSystem::Network.has_reputation_for?(name, reputation_name)
      end
    end
  end
end
