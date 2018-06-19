
describe JSS::PatchTitle do

  TEST_NAME = 'rubyjss-testPatchTitle'.freeze

  # this effectively makes the tests run in the order defined, which is
  # needed in this situattion.
  def self.test_order
    :alpha
  end

  it 'can list all patch titles' do
    JSS::PatchTitle.all.must_be_instance_of Array
    break if JSS::PatchTitle.all.empty?
    JSS::PatchTitle.all.first.must_be_instance_of Hash
    JSS::PatchTitle.all.first[:id].must_be_kind_of Integer
  end

  it 'can list all patch title name_ids' do
    JSS::PatchTitle.all_names.must_be_instance_of Array
    break if JSS::PatchTitle.all_names.empty?
    JSS::PatchTitle.all_names.first.must_be_instance_of String
  end

  it 'can list source_ids in use' do
    JSS::PatchTitle.all_source_ids.must_be_instance_of Array
    break if JSS::PatchTitle.all_source_ids.empty?
    JSS::PatchTitle.all_source_ids.first.must_be_kind_of Integer
  end

  # TODO: simplify this when we aren't reading the data via
  # XMLWorkaround
  it 'can get a patch report' do
    break if JSS::PatchTitle.all.empty?

    report = JSS::PatchTitle.patch_report JSS::PatchTitle.all_ids.sample
    report.must_be_instance_of Hash
    report.keys.must_include :versions
    report[:versions].must_be_instance_of Hash
    break if report[:versions].empty?

    vers_name = report[:versions].keys.sample
    vers_name.must_be_instance_of String
    report[:versions][vers_name].must_be_instance_of Array
    break if report[:versions][vers_name].empty?

    client = report[:versions][vers_name].sample
    client.must_be_instance_of Hash
    client[:id].must_be_kind_of Integer
  end

  def self.test_title
    return @test_title if @test_title
    src = JSS::PatchInternalSource.fetch id: 1
    unused_name_ids = src.available_name_ids - JSS::PatchTitle.all_name_ids
    puts 'Enter one of the available unused Patch Titles for testing.'
    puts 'Must be one of the following:'
    puts unused_name_ids
    @test_title ||= JSS::PatchTitle.make
  end



end
