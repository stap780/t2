module TurboStreams::CheckboxHelper
    def set_unchecked(targets: ".checkboxes")
        turbo_stream_action_tag :set_unchecked, targets: targets
    end
end
Turbo::Streams::TagBuilder.prepend(TurboStreams::CheckboxHelper)