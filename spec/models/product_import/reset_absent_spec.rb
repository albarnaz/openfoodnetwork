require 'spec_helper'

describe ProductImport::ResetAbsent do
  let(:importer) { double(:importer) }
  let(:validator) { double(:validator) }
  let(:spreadsheet_data) { double(:spreadsheet_data) }
  let(:editable_enterprises) { double(:editable_enterprises) }
  let(:import_time) { double(:import_time) }
  let(:updated_ids) { double(:updated_ids) }
  let(:import_settings) { double(:import_settings) }

  let(:entry_processor) do
    ProductImport::EntryProcessor.new(
      importer,
      validator,
      import_settings,
      spreadsheet_data,
      editable_enterprises,
      import_time,
      updated_ids
    )
  end

  let(:reset_absent) { described_class.new(entry_processor, settings) }

  describe '#call' do
    context 'when there are no settings' do
      let(:settings) do
        instance_double(
          ProductImport::Settings,
          settings: nil,
          updated_ids: [],
          enterprises_to_reset: []
        )
      end

      it 'returns nil' do
        expect(reset_absent.call).to be_nil
      end
    end

    context 'when there are no updated_ids' do
      let(:settings) do
        instance_double(
          ProductImport::Settings,
          settings: [],
          updated_ids: nil,
          enterprises_to_reset: []
        )
      end

      it 'returns nil' do
        expect(reset_absent.call).to be_nil
      end
    end

    context 'when there are no enterprises_to_reset' do
      let(:settings) do
        instance_double(
          ProductImport::Settings,
          settings: [],
          updated_ids: [],
          enterprises_to_reset: nil
        )
      end

      it 'returns nil' do
        expect(reset_absent.call).to be_nil
      end
    end

    context 'when there are settings, updated_ids and enterprises_to_reset' do
      let(:settings) do
        instance_double(
          ProductImport::Settings,
          settings: { 'reset_all_absent' => true },
          updated_ids: [0],
          enterprises_to_reset: [enterprise.id.to_s]
        )
      end

      before do
        allow(entry_processor)
          .to receive(:permission_by_id?).with(enterprise.id.to_s) { true }
      end

      context 'and not importing into inventory' do
        let(:variant) { create(:variant) }
        let(:enterprise) { variant.product.supplier }

        before do
          allow(entry_processor)
            .to receive(:importing_into_inventory?) { false }
        end

        it 'returns the number of products reset' do
          expect(reset_absent.call).to eq(2)
        end
      end

      context 'and importing into inventory' do
        let(:variant) { create(:variant) }
        let(:enterprise) { variant.product.supplier }
        let(:variant_override) do
          create(:variant_override, variant: variant, hub: enterprise)
        end

        before do
          variant_override

          allow(entry_processor)
            .to receive(:permission_by_id?).with(enterprise.id.to_s) { true }
        end

        before do
          allow(entry_processor)
            .to receive(:importing_into_inventory?) { true }
        end

        it 'returns nil' do
          expect(reset_absent.call).to be_nil
        end
      end
    end

    context 'when reset_all_absent is not set' do
      let(:settings) do
        instance_double(
          ProductImport::Settings,
          settings: { 'reset_all_absent' => false },
          updated_ids: [0],
          enterprises_to_reset: ['1']
        )
      end

      it 'does not reset anything' do
        reset_absent.call

        suppliers_to_reset_products = reset_absent
          .instance_variable_get('@suppliers_to_reset_products')
        suppliers_to_reset_inventories = reset_absent
          .instance_variable_get('@suppliers_to_reset_inventories')

        expect(suppliers_to_reset_products).to eq([])
        expect(suppliers_to_reset_inventories).to eq([])
      end
    end

    context 'the enterprise has no permission' do
      let(:settings) do
        instance_double(
          ProductImport::Settings,
          settings: { 'reset_all_absent' => true },
          updated_ids: [0],
          enterprises_to_reset: ['1']
        )
      end

      before do
        allow(entry_processor)
          .to receive(:permission_by_id?).with('1') { false }
      end

      it 'does not reset anything' do
        reset_absent.call

        suppliers_to_reset_products = reset_absent
          .instance_variable_get('@suppliers_to_reset_products')
        suppliers_to_reset_inventories = reset_absent
          .instance_variable_get('@suppliers_to_reset_inventories')

        expect(suppliers_to_reset_products).to eq([])
        expect(suppliers_to_reset_inventories).to eq([])
      end
    end
  end

  describe '#products_reset_count' do
    let(:variant) { create(:variant) }
    let(:enterprise_id) { variant.product.supplier_id }

    before do
      allow(entry_processor)
        .to receive(:permission_by_id?).with(enterprise_id.to_s) { true }

      allow(entry_processor)
        .to receive(:importing_into_inventory?) { false }
    end

    let(:settings) do
      instance_double(
        ProductImport::Settings,
        settings: { 'reset_all_absent' => true },
        updated_ids: [0],
        enterprises_to_reset: [enterprise_id.to_s]
      )
    end

    it 'returns the number of reset products or variants' do
      reset_absent.call
      expect(reset_absent.products_reset_count).to eq(2)
    end
  end
end
