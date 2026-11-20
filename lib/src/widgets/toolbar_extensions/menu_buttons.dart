// ignore_for_file: invalid_use_of_protected_member

part of '../toolbar_widget.dart';

extension ToolbarMenuButtons on ToolbarWidgetState {
  ToggleButtons _menuButtons(ContextMenuButtons t) {
    return ToggleButtons(
      constraints: BoxConstraints.tightFor(
        width: widget.toolbarOptions.toolbarItemHeight - 2,
        height: widget.toolbarOptions.toolbarItemHeight - 2,
      ),
      color: widget.toolbarOptions.buttonColor,
      selectedColor: widget.toolbarOptions.buttonSelectedColor,
      fillColor: widget.toolbarOptions.buttonFillColor,
      focusColor: widget.toolbarOptions.buttonFocusColor,
      highlightColor: widget.toolbarOptions.buttonHighlightColor,
      hoverColor: widget.toolbarOptions.buttonHoverColor,
      splashColor: widget.toolbarOptions.buttonSplashColor,
      selectedBorderColor: widget.toolbarOptions.buttonSelectedBorderColor,
      borderColor: widget.toolbarOptions.buttonBorderColor,
      borderRadius: widget.toolbarOptions.buttonBorderRadius,
      borderWidth: widget.toolbarOptions.buttonBorderWidth,
      renderBorder: widget.toolbarOptions.renderBorder,
      textStyle: widget.toolbarOptions.textStyle,
      onPressed: (int index) async {
        setState(mounted, this.setState, () {
          _menuSelected[index] = !_menuSelected[index];
        });
        final isMenuHidden = _menuSelected[index];

        var proceed = await widget.toolbarOptions.onButtonPressed
                ?.call(ButtonType.contextMenu, isMenuHidden, () {
              setState(mounted, this.setState, () {
                _menuSelected[index] = !_menuSelected[index];
              });
            }) ??
            true;

        if (proceed) {
          await widget.controller.toggleContextMenu(isMenuHidden);
        }
      },
      isSelected: _menuSelected,
      children: t.getIcons(),
    );
  }
}
