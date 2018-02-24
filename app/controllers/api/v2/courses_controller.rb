class Api::V2::CoursesController < JsonapiSuiteController
  jsonapi resource: CourseResource
  strong_resource :course

  def index
    authorize Course
    scope = CoursePolicy::Scope.new(current_user, Course, editable_only: editable_filter?).resolve
    render_jsonapi(scope)
  end

  def show
    policy_scope = policy_scope(Course.where(id: params[:id]))
    course = jsonapi_scope(policy_scope).resolve.first

    raise_not_found unless course

    render_jsonapi(course, scope: false)
  end

  def create
    authorize Course
    course, success = jsonapi_create.to_a

    if success
      render_jsonapi(course, scope: false)
    else
      render_errors_for(course)
    end
  end

  def update
    existing_course = Course.find(params[:id])
    authorize existing_course

    course, success = jsonapi_update.to_a

    if success
      render_jsonapi(course, scope: false)
    else
      render_errors_for(course)
    end
  end

  def destroy
    existing_course = Course.find(params[:id])
    authorize existing_course

    course, success = jsonapi_destroy.to_a

    if success
      render json: { meta: {} }
    else
      render_errors_for(course)
    end
  end
end
