FactoryBot.define do
  factory :course do
    name { FFaker::Product.product }

    trait :with_description do
      description { FFaker::HipsterIpsum.phrase }
    end

    factory :course_with_standard_splits do

      transient { splits_count 4 }
      transient { in_sub_splits_only false }

      after(:stub) do |course, evaluator|
        intermediate_split_bitmap = evaluator.in_sub_splits_only ? 1 : 65
        start_split = build_stubbed(:start_split)
        intermediate_splits = build_stubbed_list(:split, evaluator.splits_count - 2, sub_split_bitmap: intermediate_split_bitmap)
        finish_split = build_stubbed(:finish_split)
        splits = [start_split, intermediate_splits, finish_split].flatten

        # Align split_ids with standard split_ids generated by split_time factories
        splits.each_with_index { |split, i| split.id = 101 + i }
        splits.each { |split| split.course = course }
        temp_course_id = course.id
        course.id = nil
        course.splits = splits
        course.id = temp_course_id
      end

      after(:build) do |course, evaluator|
        build(:start_split, course: course)
        build_list(:split, evaluator.splits_count - 2, course: course)
        build(:finish_split, course: course)
      end

      after(:create) do |course, evaluator|
        create(:start_split, course: course)
        create_list(:split, evaluator.splits_count - 2, course: course)
        create(:finish_split, course: course)
      end
    end
  end
end
