class SegmentsBuilder

  def self.segments(args)
    new(args).segments
  end

  def initialize(args)
    ArgsValidator.validate(params: args,
                           required_alternatives: [:ordered_splits, :sub_splits],
                           exclusive: [:ordered_splits, :sub_splits, :working_sub_split],
                           class: self.class)
    @ordered_splits = args[:ordered_splits] || Split.where(id: args[:sub_splits].map(&:split_id)).ordered.to_a
    @sub_splits = args[:sub_splits] || sub_splits_from_splits
    @working_sub_split = args[:working_sub_split] || sub_splits.first
    validate_setup
  end

  def segments
    @segments ||= sub_splits.map do |sub_split|
      Segment.new(begin_sub_split: working_sub_split,
                  end_sub_split: sub_split,
                  begin_split: indexed_splits[working_sub_split.split_id],
                  end_split: indexed_splits[sub_split.split_id],
                  order_control: false)
    end
  end

  private

  attr_accessor :sub_splits, :ordered_splits, :working_sub_split

  def sub_splits_from_splits
    ordered_splits.map(&:sub_splits).flatten
  end

  def indexed_splits
    @indexed_splits ||= ordered_splits.index_by(&:id)
  end

  def validate_setup
    raise ArgumentError, 'sub_splits and ordered_splits do not reconcile' unless sub_splits_from_splits == sub_splits
    raise ArgumentError, 'working sub_split is not contained within the provided sub_splits' if working_sub_split && sub_splits.exclude?(working_sub_split)
  end
end