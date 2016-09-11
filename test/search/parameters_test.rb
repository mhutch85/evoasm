require_relative 'test_helper'
require 'evoasm/search/parameters'

module Search
  class ParametersTest < Minitest::Test
    def setup
      @parameters = Evoasm::Search::Parameters.new :x64
    end

    def test_kernel_size
      @parameters.kernel_size = 10
      assert_equal 10, @parameters.kernel_size

      @parameters.kernel_size = (0..100)
      assert_equal (0..100), @parameters.kernel_size
    end

    def test_adf_size
      @parameters.adf_size = 10
      assert_equal 10, @parameters.adf_size

      @parameters.adf_size = (0..100)
      assert_equal (0..100), @parameters.adf_size
    end

    def test_mutation_rate
      @parameters.mutation_rate = 0.001
      assert_in_epsilon 0.001, @parameters.mutation_rate, 0.0001

      @parameters.mutation_rate = 0.5
      assert_in_epsilon 0.5, @parameters.mutation_rate, 0.0001
    end

    def test_population_size
      @parameters.population_size = 100
      assert_equal 100, @parameters.population_size
    end

    def test_recur_limit
      @parameters.recur_limit = 1000
      assert_equal 1000, @parameters.recur_limit
    end

    def test_examples
      examples = {
        [0, 1] => 0,
        [1, 0] => 100,
        [3, 5] => 10000
      }
      @parameters.examples = examples
      assert_equal examples, @parameters.examples
    end

    def test_parameters
      parameters = %i(reg0 reg1 reg2)
      @parameters.parameters = parameters
      assert_equal parameters, @parameters.parameters

      parameters = %i(does not exist)
      assert_raises do
        @parameters.parameters = parameters
      end
    end

    def test_domains
      domains = {
        reg0: [:a, :c, :b],
        reg1: [:r11, :r12, :r13],
        imm0: (0..10)
      }

      # must set parameter before setting domain
      assert_raises ArgumentError do
        @parameters.domains = domains
      end

      @parameters.parameters = %i(reg0 reg1 imm0)
      @parameters.domains = domains

      assert_kind_of Evoasm::EnumerationDomain, @parameters.domains[:reg0]
      assert_kind_of Evoasm::RangeDomain, @parameters.domains[:imm0]
      assert_equal 0, @parameters.domains[:imm0].min
      assert_equal 10, @parameters.domains[:imm0].max
    end

    def test_instructions
      instructions = %i(adc_al_imm8 adc_rm8_r8)
      @parameters.instructions = instructions

      assert_equal instructions, @parameters.instructions
    end

    def test_validate!
      error = assert_raises Evoasm::Error do
        @parameters.validate!
      end

      # while at it, let's test Error
      assert_equal :argument, error.type
      assert_kind_of Integer, error.line
      assert_match /search-params/, error.filename
    end

  end
end
