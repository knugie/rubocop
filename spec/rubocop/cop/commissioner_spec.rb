# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe RuboCop::Cop::Commissioner do
  describe '#investigate' do
    let(:cop) do
      double(RuboCop::Cop, offenses: [], excluded_file?: false).as_null_object
    end
    let(:force) { double(RuboCop::Cop::Force).as_null_object }

    it 'returns all offenses found by the cops' do
      allow(cop).to receive(:offenses).and_return([1])

      commissioner = described_class.new([cop], [])
      source = []
      processed_source = parse_source(source)

      expect(commissioner.investigate(processed_source)).to eq [1]
    end

    context 'when a cop has no interest in the file' do
      it 'returns all offenses except the ones of the cop' do
        cops = []
        cops << double('cop A', offenses: %w(foo), excluded_file?: false)
        cops << double('cop B', offenses: %w(bar), excluded_file?: true)
        cops << double('cop C', offenses: %w(baz), excluded_file?: false)
        cops.each(&:as_null_object)

        commissioner = described_class.new(cops, [])
        source = []
        processed_source = parse_source(source)

        expect(commissioner.investigate(processed_source)).to eq %w(foo baz)
      end
    end

    it 'traverses the AST and invoke cops specific callbacks' do
      expect(cop).to receive(:on_def)

      commissioner = described_class.new([cop], [])
      source = ['def method', '1', 'end']
      processed_source = parse_source(source)

      commissioner.investigate(processed_source)
    end

    it 'passes the input params to all cops/forces that implement their own' \
       ' #investigate method' do
      source = []
      processed_source = parse_source(source)
      expect(cop).to receive(:investigate).with(processed_source)
      expect(force).to receive(:investigate).with(processed_source)

      commissioner = described_class.new([cop], [force])

      commissioner.investigate(processed_source)
    end

    it 'stores all errors raised by the cops' do
      allow(cop).to receive(:on_def) { raise RuntimeError }

      commissioner = described_class.new([cop], [])
      source = ['def method', '1', 'end']
      processed_source = parse_source(source)

      commissioner.investigate(processed_source)

      expect(commissioner.errors[cop].size).to eq(1)
      expect(commissioner.errors[cop][0]).to be_instance_of(RuntimeError)
    end

    context 'when passed :raise_error option' do
      it 're-raises the exception received while processing' do
        allow(cop).to receive(:on_def) { raise RuntimeError }

        commissioner = described_class.new([cop], [], raise_error: true)
        source = ['def method', '1', 'end']
        processed_source = parse_source(source)

        expect do
          commissioner.investigate(processed_source)
        end.to raise_error(RuntimeError)
      end
    end
  end
end
